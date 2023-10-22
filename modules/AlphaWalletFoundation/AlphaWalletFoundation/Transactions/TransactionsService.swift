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
            .sink { state in
                Task { [weak self] in
                    switch state {
                    case .didEnterBackground:
                        await self?.pause()
                    case .willEnterForeground:
                        await self?.resume()
                    }
                }
            }.store(in: &cancelable)

        sessionsProvider.sessions
            .flatMap { [weak self] sessions -> Future<[RPCServer: SingleChainTransactionProvider], Never> in
                asFuture {
                    guard let strongSelf = self else { return [:] }

                    var providers: [RPCServer: SingleChainTransactionProvider] = [:]
                    for session in sessions {
                        if let provider = strongSelf.providers[session.key] {
                            providers[session.key] = provider
                        } else {
                            providers[session.key] = await strongSelf.buildTransactionProvider(for: session.value)
                        }
                    }
                    return providers
                }
            }.handleEvents(receiveOutput: { providers in
                Task { [weak self] in
                    await self?.pauseDeleted(except: providers)
                }
            }).assign(to: \.providers, on: self)
            .store(in: &cancelable)
    }

    private func pauseDeleted(except providers: [RPCServer: SingleChainTransactionProvider]) async {
        let providersToStop = self.providers.keys.filter { !providers.keys.contains($0) }.compactMap { self.providers[$0] }
        for each in providersToStop {
            await each.pause()
        }
    }

    private func buildTransactionProvider(for session: WalletSession) async -> SingleChainTransactionProvider {
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

            await provider.start()

            return provider
        case .covalent, .oklink, .unknown:
            let provider = TransactionProvider(
                session: session,
                analytics: analytics,
                transactionDataStore: transactionDataStore,
                ercTokenDetector: ercTokenDetector,
                networking: session.blockchainExplorer)

            await provider.start()

            return provider
        }
    }

    private func pause() async {
        for each in providers {
            await each.value.pause()
        }
    }

    private func resume() async {
        guard !config.development.isAutoFetchingDisabled else { return }

        for each in providers {
            await each.value.resume()
        }
    }

    // when we receive a push notification in background we want to fetch latest transactions,
    public func fetchLatestTransactions(server: RPCServer) async -> AnyPublisher<[Transaction], PromiseError> {
        guard let provider = providers[server] else { return .empty() }

        return await provider.fetchLatestTransactions(fetchTypes: TransactionFetchType.allCases)
    }

    public func forceResumeOrStart(server: RPCServer) async {
        guard let provider = providers[server] else { return }
        switch await provider.state {
        case .pending:
            await provider.start()
        case .running:
            await provider.pause()
            await provider.resume()
        case .stopped:
            await provider.resume()
        }
    }

    public func transactionPublisher(for transactionId: String, server: RPCServer) -> AnyPublisher<Transaction?, Never> {
        transactionDataStore.transactionPublisher(for: transactionId, server: server)
            .replaceError(with: nil)
            .eraseToAnyPublisher()
    }

    public func transaction(withTransactionId transactionId: String, forServer server: RPCServer) async -> Transaction? {
        await transactionDataStore.transaction(withTransactionId: transactionId, forServer: server)
    }

    public func addSentTransaction(_ transaction: SentTransaction) {
        guard let session = sessionsProvider.session(for: transaction.original.server) else { return }

        TransactionDataStore.pendingTransactionsInformation[transaction.id] = (server: transaction.original.server, data: transaction.original.data, transactionType: transaction.original.transactionType, gasPrice: transaction.original.gasPrice)
        Task { @MainActor in
            let token: Token?
            if let address = transaction.original.to {
                token = await tokensService.token(for: address, server: transaction.original.server)
            } else {
                token = nil
            }
            let transaction = Transaction.from(from: session.account.address, transaction: transaction, token: token)
            await transactionDataStore.add(transactions: [transaction])
        }
    }
}
