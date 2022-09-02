// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Combine

public enum TransactionError: Error {
    case failedToFetch
}

public protocol TransactionsServiceDelegate: AnyObject {
    func didCompleteTransaction(in service: TransactionsService, transaction: TransactionInstance)
    func didExtractNewContracts(in service: TransactionsService, contractsAndServers: [AddressAndRPCServer])
}

public class TransactionsService {
    public let transactionDataStore: TransactionDataStore
    private let sessions: ServerDictionary<WalletSession>
    private let tokensService: DetectedContractsProvideble & TokenProvidable & TokenAddable
    private let analytics: AnalyticsLogger
    private var providers: [SingleChainTransactionProvider] = []
    private var config: Config { return sessions.anyValue.config }
    private let fetchLatestTransactionsQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Fetch Latest Transactions"
        //A limit is important for many reasons. One of which is Etherscan has a rate limit of 5 calls/sec/IP address according to https://etherscan.io/apis
        queue.maxConcurrentOperationCount = 3
        return queue
    }()

    public weak var delegate: TransactionsServiceDelegate?

    public var transactionsChangeset: AnyPublisher<[TransactionInstance], Never> {
        let servers = sessions.values.map { $0.server }
        return transactionDataStore
            .transactionsChangeset(forFilter: .all, servers: servers)
            .map { change -> [TransactionInstance] in
                switch change {
                case .initial(let transactions): return transactions
                case .update(let transactions, _, _, _): return transactions
                case .error: return []
                }
            }.eraseToAnyPublisher()
    }
    private var cancelable = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "com.TransactionsService.UpdateQueue")

    public init(sessions: ServerDictionary<WalletSession>, transactionDataStore: TransactionDataStore, analytics: AnalyticsLogger, tokensService: DetectedContractsProvideble & TokenProvidable & TokenAddable) {
        self.sessions = sessions
        self.tokensService = tokensService
        self.transactionDataStore = transactionDataStore
        self.analytics = analytics

        setupSingleChainTransactionProviders()

        NotificationCenter.default.applicationState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                switch state {
                case .didEnterBackground:
                    self?.stopTimers()
                case .willEnterForeground:
                    self?.restartTimers()
                }
            }.store(in: &cancelable)
    }

    deinit {
        fetchLatestTransactionsQueue.cancelAllOperations()
    }

    private func removeUnknownTransactions() {
        //TODO why do we remove such transactions? especially `.failed` and `.unknown`?
        transactionDataStore.removeTransactions(for: [.unknown], servers: config.enabledServers)
    }

    private func setupSingleChainTransactionProviders() {
        providers = sessions.values.map { each in
            let providerType = each.server.transactionProviderType
            let tokensFromTransactionsFetcher = TokensFromTransactionsFetcher(detectedTokens: tokensService, session: each)
            tokensFromTransactionsFetcher.delegate = self
            let provider = providerType.init(session: each, analytics: analytics, transactionDataStore: transactionDataStore, tokensService: tokensService, fetchLatestTransactionsQueue: fetchLatestTransactionsQueue, tokensFromTransactionsFetcher: tokensFromTransactionsFetcher)
            provider.delegate = self

            return provider
        }
    }

    public func start() {
        for each in providers {
            each.start()
        }

        queue.async {
            self.removeUnknownTransactions()
        }
    }

    @objc private func stopTimers() {
        for each in providers {
            each.stopTimers()
        }
    }

    @objc private func restartTimers() {
        guard !config.development.isAutoFetchingDisabled else { return }

        for each in providers {
            each.runScheduledTimers()
        }
    }

    public func fetch() {
        guard !config.development.isAutoFetchingDisabled else { return }

        for each in providers {
            each.fetch()
        }
    }

    public func transaction(withTransactionId transactionId: String, forServer server: RPCServer) -> TransactionInstance? {
        transactionDataStore.transaction(withTransactionId: transactionId, forServer: server)
    }

    public func addSentTransaction(_ transaction: SentTransaction) {
        let session = sessions[transaction.original.server]

        TransactionDataStore.pendingTransactionsInformation[transaction.id] = (server: transaction.original.server, data: transaction.original.data, transactionType: transaction.original.transactionType, gasPrice: transaction.original.gasPrice)
        let token = transaction.original.to.flatMap { tokensService.token(for: $0, server: transaction.original.server) }
        let transaction = TransactionInstance.from(from: session.account.address, transaction: transaction, token: token)
        transactionDataStore.add(transactions: [transaction])
    }

    public func stop() {
        for each in providers {
            each.stop()
        }
    }
}

extension TransactionsService: TokensFromTransactionsFetcherDelegate {

    public func didExtractTokens(in fetcher: TokensFromTransactionsFetcher, contractsAndServers: [AddressAndRPCServer], tokenUpdates: [TokenUpdate]) {
        tokensService.add(tokenUpdates: tokenUpdates)
        delegate?.didExtractNewContracts(in: self, contractsAndServers: contractsAndServers)
    }
}

extension TransactionsService: SingleChainTransactionProviderDelegate {
    public func didCompleteTransaction(transaction: TransactionInstance, in provider: SingleChainTransactionProvider) {
        delegate?.didCompleteTransaction(in: self, transaction: transaction)
    }
}
