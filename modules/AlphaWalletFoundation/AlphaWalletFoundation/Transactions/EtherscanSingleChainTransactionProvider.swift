// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import Combine
import AlphaWalletCore

class EtherscanSingleChainTransactionProvider: SingleChainTransactionProvider {
    private let transactionDataStore: TransactionDataStore
    private let session: WalletSession
    private let analytics: AnalyticsLogger
    private let fetchLatestTransactionsQueue: OperationQueue
    private let queue = DispatchQueue(label: "com.SingleChainTransaction.updateQueue")
    private var updateTransactionsTimer: Timer?
    private lazy var transactionsTracker: TransactionsTracker = {
        return TransactionsTracker(sessionID: session.sessionID)
    }()
    private let ercTokenDetector: ErcTokenDetector
    private var autoDetectErc20TransactionsOperation: AnyCancellable?
    private var autoDetectErc721TransactionsOperation: AnyCancellable?

    private var isFetchingLatestTransactions = false
    private let tokensService: TokensService
    private let apiNetworking: ApiNetworking

    private lazy var pendingTransactionProvider: PendingTransactionProvider = {
        return PendingTransactionProvider(
            session: session,
            transactionDataStore: transactionDataStore,
            ercTokenDetector: ercTokenDetector)
    }()

    init(session: WalletSession,
         analytics: AnalyticsLogger,
         transactionDataStore: TransactionDataStore,
         tokensService: TokensService,
         fetchLatestTransactionsQueue: OperationQueue,
         ercTokenDetector: ErcTokenDetector,
         apiNetworking: ApiNetworking) {

        self.apiNetworking = apiNetworking
        self.tokensService = tokensService
        self.session = session
        self.analytics = analytics
        self.transactionDataStore = transactionDataStore
        self.fetchLatestTransactionsQueue = fetchLatestTransactionsQueue
        self.ercTokenDetector = ercTokenDetector
    }

    func start() {
        pendingTransactionProvider.start()

        fetchLatestTransactions()
        runScheduledTimers()
        if transactionsTracker.fetchingState != .done {
            fetchOlderTransactions()
            autoDetectErc20Transactions()
            autoDetectErc721Transactions()
        }

        queue.async { [weak self] in
            self?.removeUnknownTransactions()
        }
    }

    func stopTimers() {
        pendingTransactionProvider.cancelScheduler()

        updateTransactionsTimer?.invalidate()
        updateTransactionsTimer = nil
    }

    func runScheduledTimers() {
        pendingTransactionProvider.resumeScheduler()

        guard updateTransactionsTimer == nil else { return }

        updateTransactionsTimer = Timer.scheduledTimer(timeInterval: 15, target: BlockOperation { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.fetchLatestTransactions()
            strongSelf.queue.async {
                strongSelf.autoDetectErc20Transactions()
                strongSelf.autoDetectErc721Transactions()
            }
        }, selector: #selector(Operation.main), userInfo: nil, repeats: true)
    }

    private func removeUnknownTransactions() {
        //TODO why do we remove such transactions? especially `.failed` and `.unknown`?
        transactionDataStore.removeTransactions(for: [.unknown], servers: [session.server])
    }

    private func autoDetectErc20Transactions() {
        guard autoDetectErc20TransactionsOperation == nil else { return }

        let server = session.server
        let wallet = session.account.address
        let startBlock = Config.getLastFetchedErc20InteractionBlockNumber(session.server, wallet: wallet).flatMap { $0 + 1 }

        autoDetectErc20TransactionsOperation = apiNetworking
            .erc20TokenTransferTransactions(startBlock: startBlock)
            .sink(receiveCompletion: { [weak self] result in
                if case .failure(let e) = result {
                    logError(e, function: #function, rpcServer: server, address: wallet)
                }
                self?.autoDetectErc20TransactionsOperation = nil
            }, receiveValue: { [weak self] transactions, maxBlockNumber in
                guard let strongSelf = self else { return }
                //Just to be sure, we don't want any kind of strange errors to clear our progress by resetting blockNumber = 0
                if maxBlockNumber > 0 {
                    Config.setLastFetchedErc20InteractionBlockNumber(maxBlockNumber, server: server, wallet: wallet)
                }
                strongSelf.addOrUpdate(transactions: transactions)
            })
    }

    private func autoDetectErc721Transactions() {
        guard autoDetectErc721TransactionsOperation == nil else { return }

        let server = session.server
        let wallet = session.account.address
        let startBlock = Config.getLastFetchedErc721InteractionBlockNumber(session.server, wallet: wallet).flatMap { $0 + 1 }

        autoDetectErc721TransactionsOperation = apiNetworking
            .erc721TokenTransferTransactions(startBlock: startBlock)
            .sink(receiveCompletion: { [weak self] result in
                if case .failure(let e) = result {
                    logError(e, function: #function, rpcServer: server, address: wallet)
                }
                self?.autoDetectErc721TransactionsOperation = nil
            }, receiveValue: { [weak self] transactions, maxBlockNumber in
                guard let strongSelf = self else { return }
                //Just to be sure, we don't want any kind of strange errors to clear our progress by resetting blockNumber = 0
                if maxBlockNumber > 0 {
                    Config.setLastFetchedErc721InteractionBlockNumber(maxBlockNumber, server: server, wallet: wallet)
                }
                strongSelf.addOrUpdate(transactions: transactions)
            })
    }

    private func addOrUpdate(transactions: [TransactionInstance]) {
        guard !transactions.isEmpty else { return }

        transactionDataStore.addOrUpdate(transactions: transactions)
        ercTokenDetector.detect(from: transactions)
    }

    ///Fetching transactions might take a long time, we use a flag to make sure we only pull the latest transactions 1 "page" at a time, otherwise we'd end up pulling the same "page" multiple times
    private func fetchLatestTransactions() {
        guard !isFetchingLatestTransactions else { return }
        isFetchingLatestTransactions = true

        let startBlock: Int
        let sortOrder: GetTransactions.SortOrder

        if let newestCachedTransaction = transactionDataStore.transactionObjectsThatDoNotComeFromEventLogs(forServer: session.server) {
            startBlock = newestCachedTransaction.blockNumber + 1
            sortOrder = .asc
        } else {
            startBlock = 1
            sortOrder = .desc
        }

        let operation = FetchLatestTransactionsOperation(provider: self, startBlock: startBlock, sortOrder: sortOrder)
        fetchLatestTransactionsQueue.addOperation(operation)
    }

    private func fetchOlderTransactions() {
        guard let oldestCachedTransaction = transactionDataStore.lastTransaction(forServer: session.server, withTransactionState: .completed) else { return }

        apiNetworking
            .normalTransactions(startBlock: 1, endBlock: oldestCachedTransaction.blockNumber - 1, sortOrder: .desc)
            .sinkAsync(receiveCompletion: { [transactionsTracker] result in
                guard case .failure = result else { return }

                transactionsTracker.fetchingState = .failed
            }, receiveValue: { [weak self] transactions in
                guard let strongSelf = self else { return }
                strongSelf.addOrUpdate(transactions: transactions)

                if transactions.isEmpty {
                    strongSelf.transactionsTracker.fetchingState = .done
                } else {
                    let timeout = DispatchTime.now() + .milliseconds(300)
                    DispatchQueue.main.asyncAfter(deadline: timeout) {
                        strongSelf.fetchOlderTransactions()
                    }
                }
            })
    }

    public func stop() {
        pendingTransactionProvider.cancelScheduler()

        updateTransactionsTimer?.invalidate()
        updateTransactionsTimer = nil
    }

    public func isServer(_ server: RPCServer) -> Bool {
        return session.server == server
    }

    //This inner class reaches into the internals of its outer coordinator class to call some methods. It exists so we can wrap operations into an Operation class and feed it into a queue, so we don't put much logic into it
    //TODO: get rid of operations, use publishers
    class FetchLatestTransactionsOperation: Operation {
        weak private var provider: EtherscanSingleChainTransactionProvider?
        private let startBlock: Int
        private let sortOrder: GetTransactions.SortOrder
        private var cancellable: AnyCancellable?
        override var isExecuting: Bool {
            return provider?.isFetchingLatestTransactions ?? false
        }
        override var isFinished: Bool {
            return !isExecuting
        }
        override var isAsynchronous: Bool {
            return true
        }

        init(provider: EtherscanSingleChainTransactionProvider, startBlock: Int, sortOrder: GetTransactions.SortOrder) {
            self.provider = provider
            self.startBlock = startBlock
            self.sortOrder = sortOrder
            super.init()
            self.queuePriority = provider.session.server.networkRequestsQueuePriority
        }

        override func main() {
            guard let provider = self.provider else { return }

            cancellable = provider.apiNetworking
                .normalTransactions(startBlock: startBlock, endBlock: 999_999_999, sortOrder: sortOrder)
                .sink(receiveCompletion: { [weak self] _ in
                    guard let strongSelf = self else { return }

                    strongSelf.willChangeValue(forKey: "isExecuting")
                    strongSelf.willChangeValue(forKey: "isFinished")

                    provider.isFetchingLatestTransactions = false

                    strongSelf.didChangeValue(forKey: "isExecuting")
                    strongSelf.didChangeValue(forKey: "isFinished")
                }, receiveValue: { [weak self] transactions in

                    guard let strongSelf = self else { return }
                    guard !strongSelf.isCancelled else { return }

                    provider.addOrUpdate(transactions: transactions)
                })
        }
    }
}
