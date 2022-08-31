//
//  CovalentSingleChainTransactionProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2022.
//

import Foundation
import Combine

public class CovalentSingleChainTransactionProvider: SingleChainTransactionProvider {
    private let transactionDataStore: TransactionDataStore
    private let session: WalletSession
    private let fetchLatestTransactionsQueue: OperationQueue
    private let analytics: AnalyticsLogger
    private let tokensFromTransactionsFetcher: TokensFromTransactionsFetcher
    private lazy var oldestTransactionProvider: OldestTransactionProvider = {
        let scheduledFetchTransactionProvider = OldestTransactionSchedulerProvider(session: session, fetchLatestTransactionsQueue: fetchLatestTransactionsQueue)
        let scheduler = Scheduler(provider: scheduledFetchTransactionProvider)
        let provider = OldestTransactionProvider(session: session, scheduler: scheduler, tokensFromTransactionsFetcher: tokensFromTransactionsFetcher, transactionDataStore: transactionDataStore)
        scheduledFetchTransactionProvider.delegate = provider

        return provider
    }()

    private lazy var pendingTransactionProvider: PendingTransactionProvider = {
        let pendingTransactionFetcher = GetPendingTransaction(server: session.server, analytics: analytics)
        return PendingTransactionProvider(session: session, transactionDataStore: transactionDataStore, tokensFromTransactionsFetcher: tokensFromTransactionsFetcher, fetcher: pendingTransactionFetcher)
    }()

    private lazy var newlyAddedTransactionProvider: NewlyAddedTransactionProvider = {
        let scheduledFetchTransactionProvider = NewlyAddedTransactionSchedulerProvider(session: session, fetchNewlyAddedTransactionsQueue: fetchLatestTransactionsQueue)
        let scheduler = Scheduler(provider: scheduledFetchTransactionProvider)
        let provider = NewlyAddedTransactionProvider(session: session, scheduler: scheduler, tokensFromTransactionsFetcher: tokensFromTransactionsFetcher, transactionDataStore: transactionDataStore)
        scheduledFetchTransactionProvider.delegate = provider

        return provider
    }()

    weak public var delegate: SingleChainTransactionProviderDelegate?

    public required init(session: WalletSession, analytics: AnalyticsLogger, transactionDataStore: TransactionDataStore, tokensService: TokenProvidable, fetchLatestTransactionsQueue: OperationQueue, tokensFromTransactionsFetcher: TokensFromTransactionsFetcher) {
        self.session = session
        self.analytics = analytics
        self.transactionDataStore = transactionDataStore
        self.fetchLatestTransactionsQueue = fetchLatestTransactionsQueue
        self.tokensFromTransactionsFetcher = tokensFromTransactionsFetcher
    }

    public func start() {
        oldestTransactionProvider.startScheduler()
        newlyAddedTransactionProvider.startScheduler()
        pendingTransactionProvider.start()
    }

    public func stopTimers() {
        oldestTransactionProvider.cancelScheduler()
        newlyAddedTransactionProvider.cancelScheduler()
        pendingTransactionProvider.cancelScheduler()
    }

    public func runScheduledTimers() {
        oldestTransactionProvider.resumeScheduler()
        newlyAddedTransactionProvider.resumeScheduler()
        pendingTransactionProvider.resumeScheduler()
    }

    public func fetch() {
        //no-op
    }

    public func stop() {
        stopTimers()
    }

    public func isServer(_ server: RPCServer) -> Bool {
        return session.server == server
    }
}
