// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import BigInt
import JSONRPCKit
import APIKit
import RealmSwift
import Result
import Moya
import TrustKeystore
import UserNotifications

enum TransactionError: Error {
    case failedToFetch
}

protocol TransactionDataCoordinatorDelegate: class {
    func didUpdate(result: ResultResult<[Transaction], TransactionError>.t)
}

class TransactionDataCoordinator {
    struct Config {
        static let deleteMissingInternalSeconds: Double = 60.0
        static let deleyedTransactionInternalSeconds: Double = 60.0
    }

    private let storage: TransactionsStorage
    private let session: WalletSession
    private let keystore: Keystore
    private let config = Config()
    private var viewModel: TransactionsViewModel {
        return .init(transactions: storage.objects)
    }
    private var timer: Timer?
    private var updateTransactionsTimer: Timer?

    private lazy var transactionsTracker: TransactionsTracker = {
        return TransactionsTracker(sessionID: session.sessionID)
    }()
    private let alphaWalletProvider = AlphaWalletProviderFactory.makeProvider()
    private var isFetchingLatestTransactions = false

    weak var delegate: TransactionDataCoordinatorDelegate?

    init(
        session: WalletSession,
        storage: TransactionsStorage,
        keystore: Keystore
    ) {
        self.session = session
        self.storage = storage
        self.keystore = keystore
        NotificationCenter.default.addObserver(self, selector: #selector(stopTimers), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(restartTimers), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    func start() {
        runScheduledTimers()
        if transactionsTracker.fetchingState != .done {
            fetchOlderTransactions(for: session.account.address)
        }
    }

    @objc func stopTimers() {
        timer?.invalidate()
        timer = nil
        updateTransactionsTimer?.invalidate()
        updateTransactionsTimer = nil
    }

    @objc func restartTimers() {
        runScheduledTimers()
    }

    private func runScheduledTimers() {
        guard !AlphaWallet.Config().isAutoFetchingDisabled else { return }
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

    func fetch() {
        session.refresh(.balance)
        fetchLatestTransactions()
        fetchPendingTransactions()
    }

    ///Fetching transactions might take a long time, we use a flag to make sure we only pull the latest transactions 1 "page" at a time, otherwise we'd end up pulling the same "page" multiple times
    @objc private func fetchLatestTransactions() {
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
        fetchTransactions(for: session.account.address, startBlock: startBlock, sortOrder: sortOrder) { [weak self] result in
            guard let strongSelf = self else { return }
            defer { strongSelf.isFetchingLatestTransactions = false }
            switch result {
            case .success(let transactions):
                strongSelf.notifyUserEtherReceived(inNewTransactions: transactions)
                strongSelf.update(items: transactions)
            case .failure(let error):
                strongSelf.handleError(error: error)
            }
        }
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
                        address: address.description,
                        startBlock: startBlock,
                        endBlock: endBlock,
                        sortOrder: sortOrder
                )
        ) { result in
            switch result {
            case .success(let response):
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let rawTransactions = try response.map(ArrayResponse<RawTransaction>.self).result
                        let transactions: [Transaction] = rawTransactions.compactMap { .from(transaction: $0) }
                        DispatchQueue.main.async {
                            completion(.success(transactions))
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

    func update(items: [PendingTransaction]) {
        let transactionItems: [Transaction] = items.compactMap { .from(transaction: $0) }
        update(items: transactionItems)
    }

    func fetchPendingTransactions() {
        storage.pendingObjects.forEach { updatePendingTransaction($0) }
    }

    private func updatePendingTransaction(_ transaction: Transaction) {
        let request = GetTransactionRequest(hash: transaction.id)
        Session.send(EtherServiceRequest(batch: BatchFactory().create(request))) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success:
                // NSLog("parsedTransaction \(_parsedTransaction)")
                if transaction.date > Date().addingTimeInterval(Config.deleyedTransactionInternalSeconds) {
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
                        if transaction.date > Date().addingTimeInterval(Config.deleteMissingInternalSeconds) {
                            strongSelf.update(state: .failed, for: transaction)
                        }
                    default: break
                    }
                default: break
                }
            }
        }
    }

    @objc func fetchPending() {
        fetchPendingTransactions()
    }

    func update(items: [Transaction]) {
        storage.add(items)
        handleUpdateItems()
    }

    func handleError(error: Error) {
        //delegate?.didUpdate(result: .failure(TransactionError.failedToFetch))
        // Avoid showing an error on failed request, instead show cached transactions.
    }

    private func notifyUserEtherReceived(inNewTransactions transactions: [Transaction]) {
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
        switch AlphaWallet.Config().server {
        case .main:
            content.body = R.string.localizable.transactionsReceivedEther(amount)
        case .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .custom, .xDai:
            content.body = R.string.localizable.transactionsReceivedEther("\(amount) (\(AlphaWallet.Config().server.name))")
        }
        content.sound = .default
        let identifier = Constants.etherReceivedNotificationIdentifier
        let request = UNNotificationRequest(identifier: "\(identifier):\(transactionId)", content: content, trigger: nil)
        notificationCenter.add(request)
    }

    func handleUpdateItems() {
        delegate?.didUpdate(result: .success(storage.objects))
    }

    func addSentTransaction(_ transaction: SentTransaction) {
        let transaction = SentTransaction.from(from: session.account.address, transaction: transaction)
        storage.add([transaction])
        handleUpdateItems()
    }

    func update(state: TransactionState, for transaction: Transaction) {
        storage.update(state: state, for: transaction)
        handleUpdateItems()
    }

    func delete(transactions: [Transaction]) {
        storage.delete(transactions)
        handleUpdateItems()
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
}
