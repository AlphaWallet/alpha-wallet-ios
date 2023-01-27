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
    private let ercTokenDetector: ErcTokenDetector
    private lazy var oldestTransactionProvider: OldestTransactionProvider = {
        let scheduledFetchTransactionProvider = OldestTransactionSchedulerProvider(session: session, networkService: networkService, fetchLatestTransactionsQueue: fetchLatestTransactionsQueue)
        let scheduler = Scheduler(provider: scheduledFetchTransactionProvider)
        let provider = OldestTransactionProvider(session: session, scheduler: scheduler, ercTokenDetector: ercTokenDetector, transactionDataStore: transactionDataStore)
        scheduledFetchTransactionProvider.delegate = provider

        return provider
    }()
    private let networkService: CovalentNetworkService
    private lazy var pendingTransactionProvider: PendingTransactionProvider = {
        return PendingTransactionProvider(session: session, transactionDataStore: transactionDataStore, ercTokenDetector: ercTokenDetector)
    }()

    private lazy var newlyAddedTransactionProvider: NewlyAddedTransactionProvider = {
        let scheduledFetchTransactionProvider = NewlyAddedTransactionSchedulerProvider(session: session, networkService: networkService, fetchNewlyAddedTransactionsQueue: fetchLatestTransactionsQueue)
        let scheduler = Scheduler(provider: scheduledFetchTransactionProvider)
        let provider = NewlyAddedTransactionProvider(session: session, scheduler: scheduler, ercTokenDetector: ercTokenDetector, transactionDataStore: transactionDataStore)
        scheduledFetchTransactionProvider.delegate = provider

        return provider
    }()

    public init(session: WalletSession,
                analytics: AnalyticsLogger,
                transactionDataStore: TransactionDataStore,
                fetchLatestTransactionsQueue: OperationQueue,
                ercTokenDetector: ErcTokenDetector,
                networkService: NetworkService) {

        self.session = session
        self.networkService = CovalentNetworkService(networkService: networkService, walletAddress: session.account.address, server: session.server)
        self.analytics = analytics
        self.transactionDataStore = transactionDataStore
        self.fetchLatestTransactionsQueue = fetchLatestTransactionsQueue
        self.ercTokenDetector = ercTokenDetector
    }

    public func start() {
        oldestTransactionProvider.startScheduler()
        newlyAddedTransactionProvider.startScheduler()
        pendingTransactionProvider.start()
        fetchLatestTransactionsQueue.addOperation { [weak self] in
            self?.removeUnknownTransactions()
        }
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

    private func removeUnknownTransactions() {
        //TODO why do we remove such transactions? especially `.failed` and `.unknown`?
        transactionDataStore.removeTransactions(for: [.unknown], servers: [session.server])
    }
}
