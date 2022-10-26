// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit

class EtherscanSingleChainTransactionProvider: SingleChainTransactionProvider {
    private let transactionDataStore: TransactionDataStore
    private let session: WalletSession
    private let analytics: AnalyticsLogger
    private let fetchLatestTransactionsQueue: OperationQueue
    private let queue = DispatchQueue(label: "com.SingleChainTransaction.updateQueue")
    private var timer: Timer?
    private var updateTransactionsTimer: Timer?
    private lazy var transactionsTracker: TransactionsTracker = {
        return TransactionsTracker(sessionID: session.sessionID)
    }()
    private let tokensFromTransactionsFetcher: TokensFromTransactionsFetcher
    private var isAutoDetectingERC20Transactions: Bool = false
    private var isAutoDetectingErc721Transactions: Bool = false
    private var isFetchingLatestTransactions = false
    private let tokensService: TokenProvidable
    private let getContractInteractions = GetContractInteractions()
    private lazy var localizedOperationFetcher = LocalizedOperationFetcher(tokensService: tokensService, session: session)
    private lazy var getPendingTransaction = GetPendingTransaction(server: session.server, analytics: analytics)
    weak public var delegate: SingleChainTransactionProviderDelegate?

    required init(
        session: WalletSession,
        analytics: AnalyticsLogger,
        transactionDataStore: TransactionDataStore,
        tokensService: TokenProvidable,
        fetchLatestTransactionsQueue: OperationQueue,
        tokensFromTransactionsFetcher: TokensFromTransactionsFetcher
    ) {
        self.tokensService = tokensService
        self.session = session
        self.analytics = analytics
        self.transactionDataStore = transactionDataStore
        self.fetchLatestTransactionsQueue = fetchLatestTransactionsQueue
        self.tokensFromTransactionsFetcher = tokensFromTransactionsFetcher
    }

    func start() {
        runScheduledTimers()
        if transactionsTracker.fetchingState != .done {
            fetchOlderTransactions()
            autoDetectERC20Transactions()
            autoDetectErc721Transactions()
        }
    }

    func stopTimers() {
        timer?.invalidate()
        timer = nil
        updateTransactionsTimer?.invalidate()
        updateTransactionsTimer = nil
    }

    func runScheduledTimers() {
        guard timer == nil, updateTransactionsTimer == nil else {
            return
        }

        timer = Timer.scheduledTimer(timeInterval: 5, target: BlockOperation { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.fetchPendingTransactions()
        }, selector: #selector(Operation.main), userInfo: nil, repeats: true)

        updateTransactionsTimer = Timer.scheduledTimer(timeInterval: 15, target: BlockOperation { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.fetchLatestTransactions()
            strongSelf.queue.async {
                strongSelf.autoDetectERC20Transactions()
                strongSelf.autoDetectErc721Transactions()
            }
        }, selector: #selector(Operation.main), userInfo: nil, repeats: true)
    }

    //TODO should this be added to the queue?
    //TODO when blockscout-compatible, this includes ERC721 too. Maybe rename?
    private func autoDetectERC20Transactions() {
        guard !isAutoDetectingERC20Transactions else { return }
        isAutoDetectingERC20Transactions = true
        let server = session.server
        let wallet = session.account.address
        let startBlock = Config.getLastFetchedErc20InteractionBlockNumber(session.server, wallet: wallet).flatMap { $0 + 1 }
        firstly {
            getContractInteractions.getErc20Interactions(walletAddress: wallet, server: server, startBlock: startBlock)
        }.then(on: queue, { [localizedOperationFetcher] transactions -> Promise<([TransactionInstance], Int)> in
            let (result, minBlockNumber, maxBlockNumber) = functional.extractBoundingBlockNumbers(fromTransactions: transactions)
            return functional.backFillTransactionGroup(result, startBlock: minBlockNumber, endBlock: maxBlockNumber, fetcher: localizedOperationFetcher).map { ($0, maxBlockNumber) }
        }).done(on: queue, { [weak self] backFilledTransactions, maxBlockNumber in
            guard let strongSelf = self else { return }
            //Just to be sure, we don't want any kind of strange errors to clear our progress by resetting blockNumber = 0
            if maxBlockNumber > 0 {
                Config.setLastFetchedErc20InteractionBlockNumber(maxBlockNumber, server: server, wallet: wallet)
            }
            strongSelf.addOrUpdate(transactions: backFilledTransactions)
        }).catch({ e in
            logError(e, function: #function, rpcServer: server, address: wallet)
        }).finally({ [weak self] in
            self?.isAutoDetectingERC20Transactions = false
        })
    }

    private func autoDetectErc721Transactions() {
        guard !isAutoDetectingErc721Transactions else { return }
        isAutoDetectingErc721Transactions = true
        let server = session.server
        let wallet = session.account.address
        let startBlock = Config.getLastFetchedErc721InteractionBlockNumber(session.server, wallet: wallet).flatMap { $0 + 1 }
        firstly {
            getContractInteractions.getErc721Interactions(walletAddress: wallet, server: server, startBlock: startBlock)
        }.then(on: queue, { [localizedOperationFetcher] transactions -> Promise<([TransactionInstance], Int)> in
            let (result, minBlockNumber, maxBlockNumber) = functional.extractBoundingBlockNumbers(fromTransactions: transactions)
            return functional.backFillTransactionGroup(result, startBlock: minBlockNumber, endBlock: maxBlockNumber, fetcher: localizedOperationFetcher).map { ($0, maxBlockNumber) }
        }).done(on: queue, { [weak self] backFilledTransactions, maxBlockNumber in
            guard let strongSelf = self else { return }
            //Just to be sure, we don't want any kind of strange errors to clear our progress by resetting blockNumber = 0
            if maxBlockNumber > 0 {
                Config.setLastFetchedErc721InteractionBlockNumber(maxBlockNumber, server: server, wallet: wallet)
            }
            strongSelf.addOrUpdate(transactions: backFilledTransactions)
        }).catch({ e in
            logError(e, rpcServer: server, address: wallet)
        }).finally({ [weak self] in
            self?.isAutoDetectingErc721Transactions = false
        })
    }

    func fetch() {
        fetchLatestTransactions()
        fetchPendingTransactions()
    }

    private func addOrUpdate(transactions: [TransactionInstance]) {
        guard !transactions.isEmpty else { return }

        transactionDataStore.addOrUpdate(transactions: transactions)
        tokensFromTransactionsFetcher.extractNewTokens(from: transactions)
    }

    private func fetchPendingTransactions() {
        for each in transactionDataStore.transactions(forServer: session.server, withTransactionState: .pending) {
            updatePendingTransaction(each )
        }
    }

    private func updatePendingTransaction(_ transaction: TransactionInstance) {
        firstly {
            getPendingTransaction.getPendingTransaction(hash: transaction.id)
        }.done(on: queue, { [weak self] pendingTransaction in
            guard let strongSelf = self else { return }

            //We can't just delete the pending transaction because it might be valid, just that the RPC node doesn't know about it
            guard let pendingTransaction = pendingTransaction else { return }
            if let blockNumber = Int(pendingTransaction.blockNumber), blockNumber > 0 {
                strongSelf.update(state: .completed, for: transaction, withPendingTransaction: pendingTransaction)
                strongSelf.addOrUpdate(transactions: [transaction])

                if let tx = strongSelf.transactionDataStore.transaction(withTransactionId: transaction.id, forServer: transaction.server) {
                    strongSelf.delegate?.didCompleteTransaction(transaction: tx, in: strongSelf)
                }
            }
        }).catch(on: queue, { [weak self] error in
            guard let strongSelf = self else { return }

            switch error as? SessionTaskError {
            case .responseError(let error):
                // TODO: Think about the logic to handle pending transactions.
                //TODO we need to detect when a transaction is marked as failed by the node?
                switch error as? JSONRPCError {
                case .responseError:
                    strongSelf.delete(transactions: [transaction])
                case .resultObjectParseError:
                    guard strongSelf.transactionDataStore.hasCompletedTransaction(withNonce: transaction.nonce, forServer: strongSelf.session.server) else { return }
                    strongSelf.delete(transactions: [transaction])
                    //The transaction might not be posted to this node yet (ie. it doesn't even think that this transaction is pending). Especially common if we post a transaction to Ethermine and fetch pending status through Etherscan
                case .responseNotFound, .errorObjectParseError, .unsupportedVersion, .unexpectedTypeObject, .missingBothResultAndError, .nonArrayResponse, .none:
                    break
                }
            case .connectionError, .requestError, .none:
                break
            }
        })
    }

    private func delete(transactions: [TransactionInstance]) {
        transactionDataStore.delete(transactions: transactions)
    }

    private func update(state: TransactionState, for transaction: TransactionInstance, withPendingTransaction pendingTransaction: PendingTransaction?) {
        transactionDataStore.update(state: state, for: transaction.primaryKey, withPendingTransaction: pendingTransaction)
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

        let promise = functional.fetchTransactions(startBlock: 1, endBlock: oldestCachedTransaction.blockNumber - 1, sortOrder: .desc, fetcher: localizedOperationFetcher)
        promise.done(on: queue, { [weak self] transactions in
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
        }).catch(on: queue, { [weak self] _ in
            guard let strongSelf = self else { return }

            strongSelf.transactionsTracker.fetchingState = .failed
        })
    }

    public func stop() {
        timer?.invalidate()
        timer = nil

        updateTransactionsTimer?.invalidate()
        updateTransactionsTimer = nil
    }

    public func isServer(_ server: RPCServer) -> Bool {
        return session.server == server
    }

    //This inner class reaches into the internals of its outer coordinator class to call some methods. It exists so we can wrap operations into an Operation class and feed it into a queue, so we don't put much logic into it
    class FetchLatestTransactionsOperation: Operation {
        weak private var provider: EtherscanSingleChainTransactionProvider?
        private let startBlock: Int
        private let sortOrder: GetTransactions.SortOrder
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
            self.queuePriority = provider.localizedOperationFetcher.server.networkRequestsQueuePriority
        }

        override func main() {
            guard let provider = self.provider else { return }

            firstly {
                EtherscanSingleChainTransactionProvider.functional.fetchTransactions(startBlock: startBlock, sortOrder: sortOrder, fetcher: provider.localizedOperationFetcher)
            }.done(on: provider.queue, { [weak self] transactions in
                guard let strongSelf = self else { return }
                guard !strongSelf.isCancelled else { return }
                provider.addOrUpdate(transactions: transactions)
            }).catch(on: provider.queue, { e in
                if e is GetTransactions.NoBlockchainExplorerApi {
                    //no-op, since this is expected for some chains
                } else {
                    logError(e, rpcServer: provider.session.server, address: provider.localizedOperationFetcher.account.address)
                }
            }).finally(on: provider.queue, { [weak self] in
                guard let strongSelf = self else { return }

                strongSelf.willChangeValue(forKey: "isExecuting")
                strongSelf.willChangeValue(forKey: "isFinished")

                provider.isFetchingLatestTransactions = false

                strongSelf.didChangeValue(forKey: "isExecuting")
                strongSelf.didChangeValue(forKey: "isFinished")
            })
        }
    }
}

extension EtherscanSingleChainTransactionProvider {
    class functional {}
}

extension EtherscanSingleChainTransactionProvider.functional {
    static func extractBoundingBlockNumbers(fromTransactions transactions: [TransactionInstance]) -> (transactions: [TransactionInstance], min: Int, max: Int) {
        let blockNumbers = transactions.map(\.blockNumber)
        if let minBlockNumber = blockNumbers.min(), let maxBlockNumber = blockNumbers.max() {
            return (transactions: transactions, min: minBlockNumber, max: maxBlockNumber)
        } else {
            return (transactions: [], min: 0, max: 0)
        }
    }

    static func fetchTransactions(startBlock: Int, endBlock: Int = 999_999_999, sortOrder: GetTransactions.SortOrder, fetcher: LocalizedOperationFetcher) -> Promise<[TransactionInstance]> {
        return firstly {
            Alamofire.request(GetTransactions(server: fetcher.server, address: fetcher.account.address, startBlock: startBlock, endBlock: endBlock, sortOrder: sortOrder)).responseData()
        }.then(on: .global()) { result -> Promise<[TransactionInstance]> in
            if result.response.response?.statusCode == 404 {
                throw URLError(URLError.Code(rawValue: 404)) // Clearer than a JSON deserialization error when it's a 404
            }

            let promises = try JSONDecoder().decode(ArrayResponse<RawTransaction>.self, from: result.data)
                .result.map { TransactionInstance.from(transaction: $0, fetcher: fetcher) }

            return when(fulfilled: promises).compactMap(on: .global()) { $0.compactMap { $0 } }
        }
    }

    static func backFillTransactionGroup(_ transactionsToFill: [TransactionInstance], startBlock: Int, endBlock: Int, fetcher: LocalizedOperationFetcher) -> Promise<[TransactionInstance]> {
        guard !transactionsToFill.isEmpty else { return .value([]) }
        return firstly {
            fetchTransactions(startBlock: startBlock, endBlock: endBlock, sortOrder: .asc, fetcher: fetcher)
        }.map(on: .global()) { fillerTransactions -> [TransactionInstance] in
            var results: [TransactionInstance] = .init()
            for each in transactionsToFill {
                //ERC20 transactions are expected to have operations because of the API we use to retrieve them from
                guard !each.localizedOperations.isEmpty else { continue }
                if var transaction = fillerTransactions.first(where: { $0.blockNumber == each.blockNumber }) {
                    transaction.isERC20Interaction = true
                    transaction.localizedOperations = each.localizedOperations
                    results.append(transaction)
                } else {
                    results.append(each)
                }
            }
            return results
        }
    }
}
