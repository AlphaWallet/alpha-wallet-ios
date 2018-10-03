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
    func didUpdate(result: Result<[Transaction], TransactionError>)
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
    private let trustProvider = TrustProviderFactory.makeProvider()
    private var previousTransactions: [Transaction]?

    weak var delegate: TransactionDataCoordinatorDelegate?

    init(
        session: WalletSession,
        storage: TransactionsStorage,
        keystore: Keystore
    ) {
        self.session = session
        self.storage = storage
        self.keystore = keystore
        NotificationCenter.default.addObserver(self, selector: #selector(stopTimers), name: .UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(restartTimers), name: .UIApplicationDidBecomeActive, object: nil)
    }

    func start() {
        runScheduledTimers()
        // Start fetching all transactions process.
        if transactionsTracker.fetchingState != .done {
            initialFetch(for: session.account.address, page: 0) { _ in }
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
        guard !Trust.Config().isAutoFetchingDisabled else { return }
        guard timer == nil, updateTransactionsTimer == nil else {
            return
        }
        timer = Timer.scheduledTimer(timeInterval: 5, target: BlockOperation { [weak self] in
            self?.fetchPending()
        }, selector: #selector(Operation.main), userInfo: nil, repeats: true)
        updateTransactionsTimer = Timer.scheduledTimer(timeInterval: 15, target: BlockOperation { [weak self] in
            self?.fetchTransactions()
        }, selector: #selector(Operation.main), userInfo: nil, repeats: true)
    }

    func fetch() {
        session.refresh(.balance)
        fetchTransactions()
        fetchPendingTransactions()
    }

    @objc func fetchTransactions() {
        let startBlock: Int = {
            guard let transaction = storage.completedObjects.first else { return 1 }
            return transaction.blockNumber - 2000
        }()
        fetchTransaction(
            for: session.account.address,
            startBlock: startBlock
        ) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let transactions):
                strongSelf.update(items: transactions)
            case .failure(let error):
                strongSelf.handleError(error: error)
            }
        }
    }

    private func fetchTransaction(
        for address: Address,
        startBlock: Int,
        page: Int = 0,
        completion: @escaping (Result<[Transaction], AnyError>) -> Void
    ) {
        NSLog("fetchTransaction: startBlock: \(startBlock), page: \(page)")

        trustProvider.request(.getTransactions(address: address.description,
                startBlock: startBlock, endBlock: 999_999_999)) { result in
            switch result {
            case .success(let response):
                do {
                    let rawTransactions = try response.map(ArrayResponse<RawTransaction>.self).result
                    let transactions: [Transaction] = rawTransactions.compactMap { .from(transaction: $0) }
                    completion(.success(transactions))
                } catch {
                    completion(.failure(AnyError(error)))
                }
            case .failure(let error):
                completion(.failure(AnyError(error)))
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

    @objc func fetchLatest() {
        fetchTransactions()
    }

    func update(items: [Transaction]) {
        storage.add(items)
        handleUpdateItems()
    }

    func handleError(error: Error) {
        //delegate?.didUpdate(result: .failure(TransactionError.failedToFetch))
        // Avoid showing an error on failed request, instead show cached transactions.
        handleUpdateItems()
    }

    private func notifyUserEtherReceivedInNewTransactions() {
        if let previousTransactions = previousTransactions {
            let diff = storage.objects - previousTransactions
            if let wallet = keystore.recentlyUsedWallet {
                let newIncomingEthTransactions = diff.filter { $0.to.sameContract(as: wallet.address.eip55String) }
                let formatter = EtherNumberFormatter.short
                for each in newIncomingEthTransactions {
                    let amount = formatter.string(from: BigInt(each.value) ?? BigInt(), decimals: 18)
                    notifyUserEtherReceived(for: each.id, amount: amount)
                }
            }
        }
        previousTransactions = storage.objects
    }

    private func notifyUserEtherReceived(for transactionId: String, amount: String) {
        let notificationCenter = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.body = R.string.localizable.transactionsReceivedEther(amount)
        content.sound = .default()
        let identifier = Constants.etherReceivedNotificationIdentifier
        let request = UNNotificationRequest(identifier: "\(identifier):\(transactionId)", content: content, trigger: nil)
        notificationCenter.add(request)
    }

    func handleUpdateItems() {
        notifyUserEtherReceivedInNewTransactions()
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

    func initialFetch(
        for address: Address,
        page: Int,
        completion: @escaping (Result<[Transaction], AnyError>) -> Void
    ) {
        fetchTransaction(for: address, startBlock: 0, page: page) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let transactions):
                strongSelf.update(items: transactions)
                if !transactions.isEmpty && page <= 50 { // page limit to 50, otherwise you have too many transactions.
                    let timeout = DispatchTime.now() + .milliseconds(300)
                    DispatchQueue.main.asyncAfter(deadline: timeout) { [weak self] in
                        self?.initialFetch(for: address, page: page + 1, completion: completion)
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
