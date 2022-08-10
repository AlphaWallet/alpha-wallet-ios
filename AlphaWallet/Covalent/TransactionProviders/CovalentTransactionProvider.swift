//
//  CovalentSingleChainTransactionProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2022.
//

import Foundation
import Combine

class CovalentSingleChainTransactionProvider: SingleChainTransactionProvider {
    private let transactionDataStore: TransactionDataStore
    private let session: WalletSession
    private let fetchLatestTransactionsQueue: OperationQueue
    private let tokensFromTransactionsFetcher: TokensFromTransactionsFetcher
    private lazy var oldestTransactionProvider: OldestTransactionProvider = {
        let scheduledFetchTransactionProvider = OldestTransactionSchedulerProvider(session: session, fetchLatestTransactionsQueue: fetchLatestTransactionsQueue)
        let scheduler = Scheduler(provider: scheduledFetchTransactionProvider)
        let provider = OldestTransactionProvider(session: session, scheduler: scheduler, tokensFromTransactionsFetcher: tokensFromTransactionsFetcher, transactionDataStore: transactionDataStore)
        scheduledFetchTransactionProvider.delegate = provider

        return provider
    }()

    private lazy var pendingTransactionProvider: PendingTransactionProvider = {
        let pendingTransactionFetcher = PendingTransactionFetcher()
        return PendingTransactionProvider(session: session, transactionDataStore: transactionDataStore, tokensFromTransactionsFetcher: tokensFromTransactionsFetcher, fetcher: pendingTransactionFetcher)
    }()

    private lazy var newlyAddedTransactionProvider: NewlyAddedTransactionProvider = {
        let scheduledFetchTransactionProvider = NewlyAddedTransactionSchedulerProvider(session: session, fetchNewlyAddedTransactionsQueue: fetchLatestTransactionsQueue)
        let scheduler = Scheduler(provider: scheduledFetchTransactionProvider)
        let provider = NewlyAddedTransactionProvider(session: session, scheduler: scheduler, tokensFromTransactionsFetcher: tokensFromTransactionsFetcher, transactionDataStore: transactionDataStore)
        scheduledFetchTransactionProvider.delegate = provider

        return provider
    }()

    weak var delegate: SingleChainTransactionProviderDelegate?

    required init(session: WalletSession, analytics: AnalyticsLogger, transactionDataStore: TransactionDataStore, tokensService: TokenProvidable, fetchLatestTransactionsQueue: OperationQueue, tokensFromTransactionsFetcher: TokensFromTransactionsFetcher) {
        self.session = session
        self.transactionDataStore = transactionDataStore
        self.fetchLatestTransactionsQueue = fetchLatestTransactionsQueue
        self.tokensFromTransactionsFetcher = tokensFromTransactionsFetcher
    }

    func start() {
        oldestTransactionProvider.startScheduler()
        newlyAddedTransactionProvider.startScheduler()
        pendingTransactionProvider.start()
    }

    func stopTimers() {
        oldestTransactionProvider.cancelScheduler()
        newlyAddedTransactionProvider.cancelScheduler()
        pendingTransactionProvider.cancelScheduler()
    }

    func runScheduledTimers() {
        oldestTransactionProvider.resumeScheduler()
        newlyAddedTransactionProvider.resumeScheduler()
        pendingTransactionProvider.resumeScheduler()
    }

    func fetch() {
        //no-op
    }

    func stop() {
        stopTimers()
    }

    func isServer(_ server: RPCServer) -> Bool {
        return session.server == server
    }
}
