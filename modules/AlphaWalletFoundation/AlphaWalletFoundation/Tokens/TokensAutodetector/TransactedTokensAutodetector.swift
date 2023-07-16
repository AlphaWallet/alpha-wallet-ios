//
//  TransactedTokensAutodetector.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 14.04.2023.
//

import Foundation
import AlphaWalletCore
import Combine

class TransactedTokensAutodetector: NSObject, TokensAutodetector {
    private let subject = PassthroughSubject<[TokenOrContract], Never>()
    private let tokensDataStore: TokensDataStore
    private var cancellable = Set<AnyCancellable>()
    private let session: WalletSession
    private var schedulers: [Scheduler]

    var detectedTokensOrContracts: AnyPublisher<[TokenOrContract], Never> {
        subject.eraseToAnyPublisher()
    }

    init(tokensDataStore: TokensDataStore,
         importToken: TokenImportable & TokenOrContractFetchable,
         session: WalletSession,
         blockchainExplorer: BlockchainExplorer,
         tokenTypes: [Eip20TokenType]) {

        self.session = session
        self.tokensDataStore = tokensDataStore

        let providers = tokenTypes.map { tokenType in
            return ContractInteractionsSchedulerProvider(
                session: session,
                blockchainExplorer: blockchainExplorer,
                storage: WalletConfig(address: session.account.address),
                tokenType: tokenType,
                interval: 60,
                stateProvider: PersistantSchedulerStateProvider(sessionID: session.sessionID, prefix: tokenType.rawValue))
        }

        schedulers = providers.map { Scheduler(provider: $0) }

        super.init()

        Publishers.MergeMany(providers.map { $0.publisher })
            .compactMap { try? $0.get() }
            .compactMap { [weak self] in self?.filter(detectedContracts: $0) }
            .flatMap { [importToken] contracts in
                let publishers = contracts.map {
                    importToken.fetchTokenOrContract(for: $0, onlyIfThereIsABalance: false).mapToResult()
                }
                return Publishers.MergeMany(publishers).collect()
            }.map { $0.compactMap { try? $0.get() } }
            .filter { !$0.isEmpty }
            .multicast(subject: subject)
            .connect()
            .store(in: &cancellable)
    }

    deinit {
        cancellable.cancellAll()
    }

    func start() {
        schedulers.forEach { $0.start() }
    }

    func stop() {
        schedulers.forEach { $0.cancel() }
    }

    func resume() {
        schedulers.forEach { $0.restart() }
    }

    private func filter(detectedContracts: [AlphaWallet.Address]) -> [AlphaWallet.Address] {
        let alreadyAddedContracts = tokensDataStore.tokens(for: [session.server]).map { $0.contractAddress }
        let deletedContracts = tokensDataStore.deletedContracts(forServer: session.server).map { $0.contractAddress }
        let hiddenContracts = tokensDataStore.hiddenContracts(forServer: session.server).map { $0.contractAddress }
        let delegateContracts = tokensDataStore.delegateContracts(forServer: session.server).map { $0.contractAddress }

        return detectedContracts - alreadyAddedContracts - deletedContracts - hiddenContracts - delegateContracts
    }
}

extension TransactedTokensAutodetector {

    private static func interactionsPaginationKey(server: RPCServer, tokenType: Eip20TokenType) -> String {
        return "interactionsPagination-\(server.chainID)-\(tokenType.rawValue)"
    }

    final class ContractInteractionsSchedulerProvider: SchedulerProvider {
        private let session: WalletSession
        private let blockchainExplorer: BlockchainExplorer
        private var storage: PaginationStorage
        private let subject = PassthroughSubject<Result<[AlphaWallet.Address], PromiseError>, Never>()
        private let tokenType: Eip20TokenType
        private let stateProvider: SchedulerStateProvider

        let interval: TimeInterval
        var name: String { "\(String(describing: self)).\(session.sessionID).\(tokenType)" }
        var operation: AnyPublisher<Void, PromiseError> {
            return fetchPublisher()
        }

        var publisher: AnyPublisher<Result<[AlphaWallet.Address], PromiseError>, Never> {
            subject.eraseToAnyPublisher()
        }

        init(session: WalletSession,
             blockchainExplorer: BlockchainExplorer,
             storage: PaginationStorage,
             tokenType: Eip20TokenType,
             interval: TimeInterval = 0,
             stateProvider: SchedulerStateProvider) {

            self.stateProvider = stateProvider
            self.interval = interval
            self.tokenType = tokenType
            self.storage = storage
            self.session = session
            self.blockchainExplorer = blockchainExplorer
        }

        private func fetchPublisher() -> AnyPublisher<Void, PromiseError> {
            guard stateProvider.state != .stopped else {
                return .fail(PromiseError(error: SchedulerError.cancelled))
            }

            //TODO remove Config instance creation
            if Config().development.isAutoFetchingDisabled {
                return .empty()
            }

            let pagination = storage.pagination(key: TransactedTokensAutodetector.interactionsPaginationKey(server: session.server, tokenType: tokenType))

            return buildFetchPublisher(walletAddress: session.account.address, pagination: pagination)
                .handleEvents(receiveOutput: { [weak self] response in
                    self?.handle(response: response)
                }, receiveCompletion: { [weak self] result in
                    guard case .failure(let e) = result else { return }
                    self?.handle(error: e)
                }).mapToVoid()
                .eraseToAnyPublisher()
        }

        private func buildFetchPublisher(walletAddress: AlphaWallet.Address,
                                         pagination: TransactionsPagination?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError> {
            switch tokenType {
            case .erc1155:
                return blockchainExplorer.erc1155TokenInteractions(walletAddress: walletAddress, pagination: pagination)
            case .erc20:
                return blockchainExplorer.erc20TokenInteractions(walletAddress: walletAddress, pagination: pagination)
            case .erc721:
                return blockchainExplorer.erc721TokenInteractions(walletAddress: walletAddress, pagination: pagination)
            }
        }

        private func handle(response: UniqueNonEmptyContracts) {
            if let nextPage = response.nextPage {
                storage.set(
                    pagination: nextPage,
                    key: TransactedTokensAutodetector.interactionsPaginationKey(server: session.server, tokenType: tokenType))
            }

            subject.send(.success(response.uniqueNonEmptyContracts))
        }

        private func handle(error: PromiseError) {
            if case BlockchainExplorerError.methodNotSupported = error.embedded {
                stateProvider.state = .stopped
            } else {
                stateProvider.state = .failured
            }

            subject.send(.failure(error))
        }
    }
}
