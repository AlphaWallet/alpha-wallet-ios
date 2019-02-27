// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import APIKit
import BigInt
import JSONRPCKit
import PromiseKit
import Result
import TrustKeystore
import UserNotifications

protocol SingleChainTransactionDataCoordinatorDelegate: class {
    func handleUpdateItems(inCoordinator: SingleChainTransactionDataCoordinator)
}

class SingleChainTransactionDataCoordinator: Coordinator {
    private let storage: TransactionsStorage
    private let session: WalletSession
    private let keystore: Keystore
    private let tokensStorage: TokensDataStore
    private let fetchLatestTransactionsQueue: OperationQueue
    private var timer: Timer?
    private var updateTransactionsTimer: Timer?
    private lazy var transactionsTracker: TransactionsTracker = {
        return TransactionsTracker(sessionID: session.sessionID)
    }()
    private let alphaWalletProvider = AlphaWalletProviderFactory.makeProvider()
    private var isFetchingLatestTransactions = false

    var coordinators: [Coordinator] = []
    weak var delegate: SingleChainTransactionDataCoordinatorDelegate?

    init(
            session: WalletSession,
            storage: TransactionsStorage,
            keystore: Keystore,
            tokensStorage: TokensDataStore,
            onFetchLatestTransactionsQueue fetchLatestTransactionsQueue: OperationQueue
    ) {
        self.session = session
        self.storage = storage
        self.keystore = keystore
        self.tokensStorage = tokensStorage
        self.fetchLatestTransactionsQueue = fetchLatestTransactionsQueue
    }

    func start() {
        runScheduledTimers()
        if transactionsTracker.fetchingState != .done {
            fetchOlderTransactions(for: session.account.address)
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
            self?.fetchPending()
        }, selector: #selector(Operation.main), userInfo: nil, repeats: true)
        updateTransactionsTimer = Timer.scheduledTimer(timeInterval: 15, target: BlockOperation { [weak self] in
            self?.fetchLatestTransactions()
        }, selector: #selector(Operation.main), userInfo: nil, repeats: true)
    }

    private func fetchPending() {
        fetchPendingTransactions()
    }

    func fetch() {
        session.refresh(.balance)
        fetchLatestTransactions()
        fetchPendingTransactions()
    }

    private func update(items: [Transaction]) {
        storage.add(items)
        delegate?.handleUpdateItems(inCoordinator: self)
    }

    private func fetchPendingTransactions() {
        storage.pendingObjects.forEach { updatePendingTransaction($0) }
    }

    private func updatePendingTransaction(_ transaction: Transaction) {
        let request = GetTransactionRequest(hash: transaction.id)
        Session.send(EtherServiceRequest(server: session.server, batch: BatchFactory().create(request))) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success:
                // NSLog("parsedTransaction \(_parsedTransaction)")
                if transaction.date > Date().addingTimeInterval(TransactionDataCoordinator.delayedTransactionInternalSeconds) {
                    strongSelf.update(state: .completed, for: transaction)
                    strongSelf.update(items: [transaction])
                }
            case .failure(let error):
                // NSLog("error: \(error)")
                switch error {
                case .responseError(let error):
                    // TODO: Think about the logic to handle pending transactions.
                    guard let error = error as? JSONRPCError else { return }
                    switch error {
                    case .responseError:
                        // NSLog("code \(code), error: \(message)")
                        strongSelf.delete(transactions: [transaction])
                    case .resultObjectParseError:
                        if transaction.date > Date().addingTimeInterval(TransactionDataCoordinator.deleteMissingInternalSeconds) {
                            strongSelf.update(state: .failed, for: transaction)
                        }
                    default: break
                    }
                default: break
                }
            }
        }
    }

    private func delete(transactions: [Transaction]) {
        storage.delete(transactions)
        delegate?.handleUpdateItems(inCoordinator: self)
    }

    private func update(state: TransactionState, for transaction: Transaction) {
        storage.update(state: state, for: transaction)
        delegate?.handleUpdateItems(inCoordinator: self)
    }

    ///Fetching transactions might take a long time, we use a flag to make sure we only pull the latest transactions 1 "page" at a time, otherwise we'd end up pulling the same "page" multiple times
    private func fetchLatestTransactions() {
        guard !isFetchingLatestTransactions else { return }
        isFetchingLatestTransactions = true

        let startBlock: Int
        let sortOrder: AlphaWalletService.SortOrder
        if let newestCachedTransaction = storage.completedObjects.first {
            startBlock = newestCachedTransaction.blockNumber + 1
            sortOrder = .asc
        } else {
            startBlock = 1
            sortOrder = .desc
        }
        let operation = FetchLatestTransactionsOperation(forSession: session, coordinator: self, startBlock: startBlock, sortOrder: sortOrder)
        fetchLatestTransactionsQueue.addOperation(operation)
    }

    private func handleError(error: Error) {
        //delegate?.didUpdate(result: .failure(TransactionError.failedToFetch))
        // Avoid showing an error on failed request, instead show cached transactions.
    }

    private func notifyUserEtherReceived(inNewTransactions transactions: [Transaction]) {
        guard !transactions.isEmpty else { return }
        guard let wallet = keystore.recentlyUsedWallet else { return }
        var toNotify: [Transaction]
        if let newestCached = storage.objects.first {
            toNotify = transactions.filter { $0.blockNumber > newestCached.blockNumber }
        } else {
            toNotify = transactions
        }
        //Beyond a certain number, it's too noisy and a performance nightmare. Eg. the first time we fetch transactions for a newly imported wallet, we might get 10,000 of them
        let maximumNumberOfNotifications = 10
        if toNotify.count > maximumNumberOfNotifications {
            toNotify = Array(toNotify[0..<maximumNumberOfNotifications])
        }
        let newIncomingEthTransactions = toNotify.filter { $0.to.sameContract(as: wallet.address.eip55String) }
        let formatter = EtherNumberFormatter.short
        let thresholdToShowNotification = Date.yesterday
        for each in newIncomingEthTransactions {
            let amount = formatter.string(from: BigInt(each.value) ?? BigInt(), decimals: 18)
            if each.date > thresholdToShowNotification {
                notifyUserEtherReceived(for: each.id, amount: amount)
            }
        }
    }

    private func notifyUserEtherReceived(for transactionId: String, amount: String) {
        let notificationCenter = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        let config = session.config
        switch session.server {
        case .main, .xDai:
            content.body = R.string.localizable.transactionsReceivedEther(amount, session.server.symbol)
        case .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .custom:
            content.body = R.string.localizable.transactionsReceivedEther("\(amount) (\(session.server.name))", session.server.symbol)
        }
        content.sound = .default
        let identifier = Constants.etherReceivedNotificationIdentifier
        let request = UNNotificationRequest(identifier: "\(identifier):\(transactionId)", content: content, trigger: nil)
        notificationCenter.add(request)
    }

    private func fetchTransactions(
            for address: Address,
            startBlock: Int,
            endBlock: Int = 999_999_999,
            sortOrder: AlphaWalletService.SortOrder,
            completion: @escaping (ResultResult<[Transaction], AnyError>.t) -> Void
    ) {
        alphaWalletProvider.request(
                .getTransactions(
                        config: session.config,
                        server: session.server,
                        address: address.description,
                        startBlock: startBlock,
                        endBlock: endBlock,
                        sortOrder: sortOrder
                )
        ) { result in
            switch result {
            case .success(let response):
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let strongSelf = self else { return }
                    do {
                        let rawTransactions = try response.map(ArrayResponse<RawTransaction>.self).result
                        DispatchQueue.main.async {
                            let transactionsPromises = rawTransactions.map { Transaction.from(transaction: $0, tokensStorage: strongSelf.tokensStorage) }
                            when(fulfilled: transactionsPromises).done { results in
                                let transactions = results.compactMap { $0 }
                                completion(.success(transactions))
                            }.cauterize()
                        }
                    } catch {
                        DispatchQueue.main.async {
                            completion(.failure(AnyError(error)))
                        }
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(AnyError(error)))
                }
            }
        }
    }

    private func fetchOlderTransactions(for address: Address) {
        guard let oldestCachedTransaction = storage.completedObjects.last else { return }

        fetchTransactions(for: address, startBlock: 1, endBlock: oldestCachedTransaction.blockNumber - 1, sortOrder: .desc) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let transactions):
                strongSelf.update(items: transactions)
                if !transactions.isEmpty {
                    let timeout = DispatchTime.now() + .milliseconds(300)
                    DispatchQueue.main.asyncAfter(deadline: timeout) { [weak self] in
                        self?.fetchOlderTransactions(for: address)
                    }
                } else {
                    strongSelf.transactionsTracker.fetchingState = .done
                }
            case .failure:
                strongSelf.transactionsTracker.fetchingState = .failed
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil

        updateTransactionsTimer?.invalidate()
        updateTransactionsTimer = nil
    }

    func isServer(_ server: RPCServer) -> Bool {
        return session.server == server
    }

    //This inner class reaches into the internals of SingleChainTransactionDataCoordinator to call some methods. It exists so we can wrap operations into an Operation class and feed it into a queue, so we don't put much logic into it
    class FetchLatestTransactionsOperation: Operation {
        private let session: WalletSession
        weak private var coordinator: SingleChainTransactionDataCoordinator?
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

        init(forSession session: WalletSession, coordinator: SingleChainTransactionDataCoordinator, startBlock: Int, sortOrder: AlphaWalletService.SortOrder) {
            self.session = session
            self.coordinator = coordinator
            self.startBlock = startBlock
            self.sortOrder = sortOrder
            super.init()
            self.queuePriority = session.server.networkRequestsQueuePriority
        }

        override func main() {
            coordinator?.fetchTransactions(for: session.account.address, startBlock: startBlock, sortOrder: sortOrder) { [weak self] result in
                guard let strongSelf = self else { return }
                guard let coordinator = self?.coordinator else { return }
                defer {
                    strongSelf.willChangeValue(forKey: "isExecuting")
                    strongSelf.willChangeValue(forKey: "isFinished")
                    coordinator.isFetchingLatestTransactions = false
                    strongSelf.didChangeValue(forKey: "isExecuting")
                    strongSelf.didChangeValue(forKey: "isFinished")
                }
                switch result {
                case .success(let transactions):
                    strongSelf.coordinator?.notifyUserEtherReceived(inNewTransactions: transactions)
                    strongSelf.coordinator?.update(items: transactions)
                case .failure(let error):
                    strongSelf.coordinator?.handleError(error: error)
                }
            }
        }
    }
}
