//
//  TokenRepairService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.08.2022.
//

import Foundation
import Combine
import AlphaWalletCore
import CombineExt

final class TokenRepairService {
    enum RepairTokenError: Error {
        case inner(ImportToken.ImportTokenError)
        case sessionNotFound(server: RPCServer)
        case wrongResponse
    }

    private let tokensDataStore: TokensDataStore
    private let sessionsProvider: SessionsProvider
    private var cancelable = Set<AnyCancellable>()
    private var operations: [AddressAndRPCServer: AnyCancellable] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.\(String(describing: TokenRepairService.self))", qos: .utility)

    init(tokensDataStore: TokensDataStore, sessionsProvider: SessionsProvider) {
        self.tokensDataStore = tokensDataStore
        self.sessionsProvider = sessionsProvider
    }

    func start() {
        let spuriousTokens = sessionsProvider.sessions
            .map { Array($0.keys) }
            .flatMapLatest { [tokensDataStore] in tokensDataStore.tokensChangesetPublisher(for: $0, predicate: TokenRepairService.spuriousTokensPredicate()) }
            .receive(on: queue)
            .map { changeset -> ChangeSet<[AddressAndRPCServer]> in
                switch changeset {
                case .initial(let tokens):
                    let tokens = tokens.map { AddressAndRPCServer(address: $0.contractAddress, server: $0.server) }
                    return .initial(tokens)
                case .update(let tokens, let deletions, let insertions, let modifications):
                    let tokens = tokens.map { AddressAndRPCServer(address: $0.contractAddress, server: $0.server) }

                    return .update(tokens, deletions: deletions, insertions: insertions, modifications: modifications)
                case .error(let e):
                    return .error(e)
                }
            }

        let delegateContracts = sessionsProvider.sessions
            .map { Array($0.keys) }
            .flatMapLatest { [tokensDataStore] in tokensDataStore.delegateContractsChangeset(for: $0) }
            .receive(on: queue)

        Publishers.Merge(delegateContracts, spuriousTokens)
            .sink(receiveValue: { [weak self] changeset in
                switch changeset {
                case .initial(let data):
                    data.forEach { self?.startOperation(for: $0) }
                case .update(let contracts, let deletions, let insertions, _):
                    insertions.map { contracts[$0] }.forEach { self?.startOperation(for: $0) }
                    deletions.map { contracts[$0] }.forEach { self?.cancelOperation(for: $0) }
                case .error:
                    self?.cancelAllOperations()
                }
            }).store(in: &cancelable)
    }

    private func buildFetchTokenOrContractOperation(for delegateContract: AddressAndRPCServer) -> AnyPublisher<TokenOrContract, RepairTokenError> {
        func fetchPublisher(contract: AlphaWallet.Address, fetcher: TokenOrContractFetchable) -> AnyPublisher<TokenOrContract, RepairTokenError> {
            return Just(delegateContract)
                .setFailureType(to: RepairTokenError.self)
                .flatMap { _ -> AnyPublisher<TokenOrContract, RepairTokenError> in
                    return fetcher.fetchTokenOrContract(for: contract)
                        .mapError { RepairTokenError.inner($0) }
                        .flatMap { tokenOrContract -> AnyPublisher<TokenOrContract, RepairTokenError> in
                            switch tokenOrContract {
                            case .ercToken(let token): return .just(tokenOrContract)
                            case .delegateContracts: return .fail(RepairTokenError.wrongResponse)
                            case .deletedContracts:  return .just(tokenOrContract)
                            }
                        }.eraseToAnyPublisher()
                }.retry(.randomDelayed(retries: UInt.max, delayBeforeRetry: 10, delayUpperRangeValueFrom0To: 30), scheduler: RunLoop.main)
                .eraseToAnyPublisher()
        }

        return sessionsProvider.sessions
            .map { $0[safe: delegateContract.server] }
            .removeDuplicates()
            .setFailureType(to: RepairTokenError.self)
            .flatMapLatest { session -> AnyPublisher<TokenOrContract, RepairTokenError> in
                guard let session = session else {
                    return .fail(.sessionNotFound(server: delegateContract.server))
                }

                return fetchPublisher(contract: delegateContract.address, fetcher: session.importToken)
            }.eraseToAnyPublisher()
    }

    private func startOperation(for delegateContract: AddressAndRPCServer) {
        guard operations[delegateContract] == nil else { return }

        operations[delegateContract] = buildFetchTokenOrContractOperation(for: delegateContract)
            .receive(on: queue)
            .sink(receiveCompletion: { [weak self] _ in
                self?.cancelOperation(for: delegateContract)
            }, receiveValue: { [tokensDataStore] tokenOrContract in
                switch tokenOrContract {
                case .delegateContracts:
                    break // no-op
                case .ercToken, .deletedContracts:
                    Task {
                        var actions: [AddOrUpdateTokenAction] = []
                        switch tokenOrContract {
                        case .ercToken(let ercToken):
                            actions += [.add(ercToken: ercToken, shouldUpdateBalance: false)]
                        case .delegateContracts(let delegateContracts):
                            actions += [.addOrUpdateDelegateContracts(delegateContracts: delegateContracts)]
                        case .deletedContracts(let deletedContracts):
                            actions += [.addOrUpdateDeletedContracts(deletedContracts: deletedContracts)]
                        }
                        actions += [.deleteDeletedContracts(deletedContracts: [delegateContract])]
                        await tokensDataStore.addOrUpdate(with: actions)
                    }
                }
            })
    }

    private func cancelAllOperations() {
        for operation in operations {
            operation.value.cancel()
        }
        operations.removeAll()
    }

    private func cancelOperation(for delegateContract: AddressAndRPCServer) {
        guard let operation = operations[delegateContract] else { return }
        operations[delegateContract] = .none

        operation.cancel()
    }

    private static func spuriousTokensPredicate() -> NSPredicate {
        func matches(tokenTypes: [TokenType]) -> NSPredicate {
            return NSPredicate(format: "rawType IN %@", tokenTypes.map { $0.rawValue })
        }

        func emptyName() -> NSPredicate {
            NSPredicate(format: "name == ''")
        }

        func emptySymbol() -> NSPredicate {
            NSPredicate(format: "symbol == ''")
        }

        func zeroDecimals() -> NSPredicate {
            NSPredicate(format: "decimals == 0")
        }

        let isSpuriousFungibleToken = NSCompoundPredicate(andPredicateWithSubpredicates: [
            matches(tokenTypes: [.nativeCryptocurrency, .erc20]),
            NSCompoundPredicate(andPredicateWithSubpredicates: [emptyName(), emptySymbol(), zeroDecimals()])
        ])

        let isSpuriousNonfungibleToken = NSCompoundPredicate(andPredicateWithSubpredicates: [
            matches(tokenTypes: [.erc875, .erc721, .erc721ForTickets]),
            NSCompoundPredicate(orPredicateWithSubpredicates: [emptyName(), emptySymbol()])
        ])

        return NSCompoundPredicate(orPredicateWithSubpredicates: [
            isSpuriousFungibleToken,
            isSpuriousNonfungibleToken
        ])
    }
}
