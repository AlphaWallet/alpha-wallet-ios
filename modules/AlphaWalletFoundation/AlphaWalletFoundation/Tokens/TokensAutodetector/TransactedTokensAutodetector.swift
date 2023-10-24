//
//  TransactedTokensAutodetector.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 14.04.2023.
//

import Foundation
import AlphaWalletCore
import Combine

actor TransactedTokensAutodetector: NSObject, TokensAutodetector {
    private let subject = PassthroughSubject<[TokenOrContract], Never>()
    private let tokensDataStore: TokensDataStore
    private var cancellable = Set<AnyCancellable>()
    private let session: WalletSession
    private let schedulers: [Scheduler]

    nonisolated var detectedTokensOrContracts: AnyPublisher<[TokenOrContract], Never> {
        subject.eraseToAnyPublisher()
    }

    init(tokensDataStore: TokensDataStore, importToken: TokenImportable & TokenOrContractFetchable, session: WalletSession, blockchainExplorer: BlockchainExplorer, tokenTypes: [EipTokenType]) {
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
            .flatMap { contracts in
                asFuture {
                    await self.filter(detectedContracts: contracts)
                }
            }
            .flatMap { [importToken] contracts in
                let publishers = contracts.map {
                    importToken.fetchTokenOrContract(for: $0, onlyIfThereIsABalance: false).mapToResult()
                }
                //Arbitrary number that is not too big and not too small so we get a chance to process and finish auto-detecting some tokens without waiting for a few hundred to finish
                //TODO for wallets that transacted with many tokens, this (the whole process of auto-detecting, not just a single batch in the next line) can take more than 10 minutes to process. We ought to save the contracts that have been detected but not processed yet. Otherwise we would have scrolled past that in the blockchain explorer history and if the app suspended, crashes or gets killed, we'll miss those tokens
                return Publishers.MergeMany(publishers).collect(30)
            }.map { $0.compactMap { try? $0.get() } }
            .filter { !$0.isEmpty }
            .multicast(subject: subject)
            .connect()
            .store(in: &cancellable)
    }

    deinit {
        cancellable.cancellAll()
    }

    nonisolated func start() async {
        schedulers.forEach { $0.start() }
    }

    nonisolated func stop() {
        schedulers.forEach { $0.cancel() }
    }

    nonisolated func resume() {
        schedulers.forEach { $0.restart() }
    }

    private nonisolated func filter(detectedContracts: [AlphaWallet.Address]) async -> [AlphaWallet.Address] {
        let alreadyAddedContracts = await tokensDataStore.tokens(for: [session.server]).map { $0.contractAddress }
        let deletedContracts = await tokensDataStore.deletedContracts(forServer: session.server).map { $0.contractAddress }
        let hiddenContracts = await tokensDataStore.hiddenContracts(forServer: session.server).map { $0.contractAddress }
        let delegateContracts = await tokensDataStore.delegateContracts(forServer: session.server).map { $0.contractAddress }

        return detectedContracts - alreadyAddedContracts - deletedContracts - hiddenContracts - delegateContracts
    }
}

extension TransactedTokensAutodetector {

    private static func interactionsPaginationKey(server: RPCServer, tokenType: EipTokenType) -> String {
        return "interactionsPagination-\(server.chainID)-\(tokenType.rawValue)"
    }

    final class ContractInteractionsSchedulerProvider: SchedulerProvider {
        private let session: WalletSession
        private let blockchainExplorer: BlockchainExplorer
        private var storage: PaginationStorage
        private let subject = PassthroughSubject<Result<[AlphaWallet.Address], PromiseError>, Never>()
        private let tokenType: EipTokenType
        private let stateProvider: SchedulerStateProvider

        let interval: TimeInterval
        var name: String { "\(String(describing: self)).\(session.sessionID).\(tokenType)" }
        var operation: AnyPublisher<Void, PromiseError> {
            return fetchPublisher()
        }

        var publisher: AnyPublisher<Result<[AlphaWallet.Address], PromiseError>, Never> {
            subject.eraseToAnyPublisher()
        }

        init(session: WalletSession, blockchainExplorer: BlockchainExplorer, storage: PaginationStorage, tokenType: EipTokenType, interval: TimeInterval, stateProvider: SchedulerStateProvider) {
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

