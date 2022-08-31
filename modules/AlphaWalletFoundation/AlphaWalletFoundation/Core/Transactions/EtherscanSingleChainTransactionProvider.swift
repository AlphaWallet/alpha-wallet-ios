// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import APIKit
import BigInt
import JSONRPCKit
import Moya
import PromiseKit

public class EtherscanSingleChainTransactionProvider: SingleChainTransactionProvider {
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
    private let alphaWalletProvider = AlphaWalletProviderFactory.makeProvider()
    private let tokensFromTransactionsFetcher: TokensFromTransactionsFetcher
    private var isAutoDetectingERC20Transactions: Bool = false
    private var isAutoDetectingErc721Transactions: Bool = false
    private var isFetchingLatestTransactions = false
    private let tokensService: TokenProvidable
    private lazy var getPendingTransaction = GetPendingTransaction(server: session.server, analytics: analytics)
    weak public var delegate: SingleChainTransactionProviderDelegate?

    public required init(
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

    public func start() {
        runScheduledTimers()
        if transactionsTracker.fetchingState != .done {
            fetchOlderTransactions()
            autoDetectERC20Transactions()
            autoDetectErc721Transactions()
        }
    }

    public func stopTimers() {
        timer?.invalidate()
        timer = nil
        updateTransactionsTimer?.invalidate()
        updateTransactionsTimer = nil
    }

    public func runScheduledTimers() {
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
            GetContractInteractions(queue: queue)
                .getErc20Interactions(walletAddress: wallet, server: server, startBlock: startBlock)
        }.then(on: queue, { [weak self] result -> Promise<([TransactionInstance], Int)> in
            guard let strongSelf = self else { return .init(error: PMKError.cancelled) }

            let (result, minBlockNumber, maxBlockNumber) = functional.extractBoundingBlockNumbers(fromTransactions: result)
            return functional.backFillTransactionGroup(result, startBlock: minBlockNumber, endBlock: maxBlockNumber, session: strongSelf.session, alphaWalletProvider: strongSelf.alphaWalletProvider, tokensService: strongSelf.tokensService, queue: strongSelf.queue).map { ($0, maxBlockNumber) }
        }).done(on: queue, { [weak self] backFilledTransactions, maxBlockNumber in
            guard let strongSelf = self else { return }
            //Just to be sure, we don't want any kind of strange errors to clear our progress by resetting blockNumber = 0
            if maxBlockNumber > 0 {
                Config.setLastFetchedErc20InteractionBlockNumber(maxBlockNumber, server: server, wallet: wallet)
            }
            strongSelf.addOrUpdate(transactions: backFilledTransactions)
        }).catch({ e in
            error(value: e, function: #function, rpcServer: server, address: wallet)
        })
        .finally { [weak self] in
            self?.isAutoDetectingERC20Transactions = false
        }
    }

    private func autoDetectErc721Transactions() {
        guard !isAutoDetectingErc721Transactions else { return }
        isAutoDetectingErc721Transactions = true
        let server = session.server
        let wallet = session.account.address
        let startBlock = Config.getLastFetchedErc721InteractionBlockNumber(session.server, wallet: wallet).flatMap { $0 + 1 }
        firstly {
            GetContractInteractions(queue: queue)
                .getErc721Interactions(walletAddress: wallet, server: server, startBlock: startBlock)
        }.then(on: queue, { [weak self] result -> Promise<([TransactionInstance], Int)> in
            guard let strongSelf = self else { return .init(error: PMKError.cancelled) }
            let (result, minBlockNumber, maxBlockNumber) = functional.extractBoundingBlockNumbers(fromTransactions: result)
            return functional.backFillTransactionGroup(result, startBlock: minBlockNumber, endBlock: maxBlockNumber, session: strongSelf.session, alphaWalletProvider: strongSelf.alphaWalletProvider, tokensService: strongSelf.tokensService, queue: strongSelf.queue).map { ($0, maxBlockNumber) }
        }).done(on: queue, { [weak self] backFilledTransactions, maxBlockNumber in
            guard let strongSelf = self else { return }
            //Just to be sure, we don't want any kind of strange errors to clear our progress by resetting blockNumber = 0
            if maxBlockNumber > 0 {
                Config.setLastFetchedErc721InteractionBlockNumber(maxBlockNumber, server: server, wallet: wallet)
            }
            strongSelf.addOrUpdate(transactions: backFilledTransactions)
        }).catch({ e in
            error(value: e, rpcServer: server, address: wallet)
        })
        .finally { [weak self] in
            self?.isAutoDetectingErc721Transactions = false
        }
    }

    public func fetch() {
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
        let sortOrder: AlphaWalletService.SortOrder

        if let newestCachedTransaction = transactionDataStore.transactionObjectsThatDoNotComeFromEventLogs(forServer: session.server) {
            startBlock = newestCachedTransaction.blockNumber + 1
            sortOrder = .asc
        } else {
            startBlock = 1
            sortOrder = .desc
        }

        let operation = FetchLatestTransactionsOperation(forSession: session, coordinator: self, startBlock: startBlock, sortOrder: sortOrder, queue: queue)
        fetchLatestTransactionsQueue.addOperation(operation)
    }

    private func fetchOlderTransactions() {
        guard let oldestCachedTransaction = transactionDataStore.lastTransaction(forServer: session.server, withTransactionState: .completed) else { return }

        let promise = functional.fetchTransactions(startBlock: 1, endBlock: oldestCachedTransaction.blockNumber - 1, sortOrder: .desc, session: session, alphaWalletProvider: alphaWalletProvider, tokensService: tokensService, queue: queue)
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
        private let session: WalletSession
        weak private var coordinator: EtherscanSingleChainTransactionProvider?
        private let startBlock: Int
        private let sortOrder: AlphaWalletService.SortOrder
        override var isExecuting: Bool {
            return coordinator?.isFetchingLatestTransactions ?? false
        }
        override var isFinished: Bool {
            return !isExecuting
        }
        override var isAsynchronous: Bool {
            return true
        }
        private let queue: DispatchQueue

        init(forSession session: WalletSession, coordinator: EtherscanSingleChainTransactionProvider, startBlock: Int, sortOrder: AlphaWalletService.SortOrder, queue: DispatchQueue) {
            self.session = session
            self.coordinator = coordinator
            self.startBlock = startBlock
            self.sortOrder = sortOrder
            self.queue = queue
            super.init()
            self.queuePriority = session.server.networkRequestsQueuePriority
        }

        override func main() {
            guard let coordinator = self.coordinator else { return }

            firstly {
                EtherscanSingleChainTransactionProvider.functional.fetchTransactions(startBlock: startBlock, sortOrder: sortOrder, session: coordinator.session, alphaWalletProvider: coordinator.alphaWalletProvider, tokensService: coordinator.tokensService, queue: coordinator.queue)
            }.done(on: queue, { [weak self] transactions in
                guard let strongSelf = self else { return }
                guard !strongSelf.isCancelled else { return }
                coordinator.addOrUpdate(transactions: transactions)
            }).catch(on: queue, { e in
                error(value: e, rpcServer: coordinator.session.server, address: self.session.account.address)
            }).finally(on: queue, { [weak self] in
                guard let strongSelf = self else { return }

                strongSelf.willChangeValue(forKey: "isExecuting")
                strongSelf.willChangeValue(forKey: "isFinished")

                coordinator.isFetchingLatestTransactions = false

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

    static func fetchTransactions(startBlock: Int, endBlock: Int = 999_999_999, sortOrder: AlphaWalletService.SortOrder, session: WalletSession, alphaWalletProvider: MoyaProvider<AlphaWalletService>, tokensService: TokenProvidable, queue: DispatchQueue) -> Promise<[TransactionInstance]> {
        let target: AlphaWalletService = .getTransactions(server: session.server, address: session.account.address, startBlock: startBlock, endBlock: endBlock, sortOrder: sortOrder)
        return firstly {
            alphaWalletProvider.request(target)
        }.then(on: queue) { response -> Promise<[TransactionInstance]> in
            if response.statusCode == 404 {
                //Clearer than a JSON deserialization error when it's a 404
                enum E: Error {
                    case statusCode404
                }
                throw E.statusCode404
            }
            let promises = try response.map(ArrayResponse<RawTransaction>.self).result.map {
                TransactionInstance.from(transaction: $0, tokensService: tokensService, session: session)
            }

            return when(fulfilled: promises).compactMap(on: queue) {
                $0.compactMap { $0 }
            }
        }
    }

    static func backFillTransactionGroup(_ transactionsToFill: [TransactionInstance], startBlock: Int, endBlock: Int, session: WalletSession, alphaWalletProvider: MoyaProvider<AlphaWalletService>, tokensService: TokenProvidable, queue: DispatchQueue) -> Promise<[TransactionInstance]> {
        guard !transactionsToFill.isEmpty else { return .value([]) }
        return firstly {
            fetchTransactions(startBlock: startBlock, endBlock: endBlock, sortOrder: .asc, session: session, alphaWalletProvider: alphaWalletProvider, tokensService: tokensService, queue: queue)
        }.map(on: queue) { fillerTransactions -> [TransactionInstance] in
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

func error(value e: Error, pref: String = "", function f: String = #function, rpcServer: RPCServer? = nil, address: AlphaWallet.Address? = nil) {
    var description = pref
    description += rpcServer.flatMap { " server: \($0)" } ?? ""
    description += address.flatMap { " address: \($0.eip55String)" } ?? ""
    description += " \(e)"
    warnLog(description, callerFunctionName: f)
}
