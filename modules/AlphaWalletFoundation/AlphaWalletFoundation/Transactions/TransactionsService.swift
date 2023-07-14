// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Combine
import AlphaWalletCore

public class TransactionsService {
    private let transactionDataStore: TransactionDataStore
    private let sessionsProvider: SessionsProvider
    private let tokensService: TokensService
    private let analytics: AnalyticsLogger
    private var providers: [RPCServer: SingleChainTransactionProvider] = [:]
    private let config: Config

    public func transactions(filter: TransactionsFilterStrategy) -> AnyPublisher<[Transaction], Never> {
        return sessionsProvider.sessions
            .flatMapLatest { [transactionDataStore] sessions -> AnyPublisher<[Transaction], Never> in
                let servers = sessions.values.map { $0.server }
                return transactionDataStore
                    .transactionsChangeset(filter: filter, servers: servers)
                    .map { changeset -> [Transaction] in
                        switch changeset {
                        case .initial(let transactions): return transactions
                        case .error: return .init()
                        case .update(let transactions, let deletions, let insertions, let modifications):
                            return insertions.map { transactions[$0] } + modifications.map { transactions[$0] } - deletions.map { transactions[$0] }
                        }
                    }.eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }

    private var cancelable = Set<AnyCancellable>()
    private let networkService: NetworkService
    private let assetDefinitionStore: AssetDefinitionStore

    public init(sessionsProvider: SessionsProvider,
                transactionDataStore: TransactionDataStore,
                analytics: AnalyticsLogger,
                tokensService: TokensService,
                networkService: NetworkService,
                config: Config,
                assetDefinitionStore: AssetDefinitionStore) {

        self.config = config
        self.sessionsProvider = sessionsProvider
        self.tokensService = tokensService
        self.transactionDataStore = transactionDataStore
        self.analytics = analytics
        self.networkService = networkService
        self.assetDefinitionStore = assetDefinitionStore

        NotificationCenter.default.applicationState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                switch state {
                case .didEnterBackground:
                    self?.pause()
                case .willEnterForeground:
                    self?.resume()
                }
            }.store(in: &cancelable)

        sessionsProvider.sessions
            .map { [weak self] sessions -> [RPCServer: SingleChainTransactionProvider] in
                guard let strongSelf = self else { return [:] }

                var providers: [RPCServer: SingleChainTransactionProvider] = [:]
                for session in sessions {
                    if let provider = strongSelf.providers[session.key] {
                        providers[session.key] = provider
                    } else {
                        providers[session.key] = strongSelf.buildTransactionProvider(for: session.value)
                    }
                }
                return providers
            }.handleEvents(receiveOutput: { [weak self] in self?.pauseDeleted(except: $0) })
            .assign(to: \.providers, on: self)
            .store(in: &cancelable)
    }

    private func pauseDeleted(except providers: [RPCServer: SingleChainTransactionProvider]) {
        let providersToStop = self.providers.keys.filter { !providers.keys.contains($0) }.compactMap { self.providers[$0] }
        providersToStop.forEach { $0.pause() }
    }

    private func buildTransactionProvider(for session: WalletSession) -> SingleChainTransactionProvider {
        let ercTokenDetector = ErcTokenDetector(
            tokensService: tokensService,
            server: session.server,
            ercProvider: session.tokenProvider,
            assetDefinitionStore: assetDefinitionStore)

        switch session.server.transactionsSource {
        case .blockscout, .etherscan:
            let transporter = BaseApiTransporter()
            let provider = EtherscanSingleChainTransactionProvider(
                session: session,
                analytics: analytics,
                transactionDataStore: transactionDataStore,
                ercTokenDetector: ercTokenDetector,
                blockchainExplorer: session.blockchainExplorer)

            provider.start()

            return provider
        case .covalent, .oklink, .unknown:
            let provider = TransactionProvider(
                session: session,
                analytics: analytics,
                transactionDataStore: transactionDataStore,
                ercTokenDetector: ercTokenDetector,
                networking: session.blockchainExplorer)

            provider.start()

            return provider
        }
    }

    @objc private func pause() {
        for each in providers {
            each.value.pause()
        }
    }

    @objc private func resume() {
        guard !config.development.isAutoFetchingDisabled else { return }

        for each in providers {
            each.value.resume()
        }
    }

    // when we receive a push notification in background we want to fetch latest transactions,
    public func fetchLatestTransactions(server: RPCServer) -> AnyPublisher<[Transaction], PromiseError> {
        guard let provider = providers[server] else { return .empty() }

        return provider.fetchLatestTransactions(fetchTypes: TransactionFetchType.allCases)
    }

    public func forceResumeOrStart(server: RPCServer) {
        guard let provider = providers[server] else { return }

        switch provider.state {
        case .pending:
            provider.start()
        case .running:
            provider.pause()
            provider.resume()
        case .stopped:
            provider.resume()
        }
    }

    public func transactionPublisher(for transactionId: String, server: RPCServer) -> AnyPublisher<Transaction?, Never> {
        transactionDataStore.transactionPublisher(for: transactionId, server: server)
            .replaceError(with: nil)
            .eraseToAnyPublisher()
    }

    public func transaction(withTransactionId transactionId: String, forServer server: RPCServer) -> Transaction? {
        transactionDataStore.transaction(withTransactionId: transactionId, forServer: server)
    }

    public func addSentTransaction(_ transaction: SentTransaction) {
        guard let session = sessionsProvider.session(for: transaction.original.server) else { return }

        TransactionDataStore.pendingTransactionsInformation[transaction.id] = (server: transaction.original.server, data: transaction.original.data, transactionType: transaction.original.transactionType, gasPrice: transaction.original.gasPrice)
        let token = transaction.original.to.flatMap { tokensService.token(for: $0, server: transaction.original.server) }
        let transaction = Transaction.from(from: session.account.address, transaction: transaction, token: token)

        transactionDataStore.add(transactions: [transaction])
    }
}
