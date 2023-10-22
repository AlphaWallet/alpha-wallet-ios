//
//  PendingTransactionProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.04.2022.
//

import Foundation
import AlphaWalletCore
import BigInt
import Combine

public final actor PendingTransactionProvider {
    public enum PendingTransactionProviderError: Error {
        case `internal`(Error)
        case failureToRetrieveTransaction(hash: String, error: Error)
    }

    private let session: WalletSession
    private let transactionDataStore: TransactionDataStore
    private let ercTokenDetector: ErcTokenDetector
    private var cancelable = Set<AnyCancellable>()
    private let fetchPendingTransactionsQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Auto-update Pending Transactions"
        queue.maxConcurrentOperationCount = 5

        return queue
    }()
    private let completeTransactionSubject = PassthroughSubject<Result<Transaction, PendingTransactionProviderError>, Never>()
    private lazy var store: [String: SchedulerProtocol] = [:]

    public nonisolated var completeTransaction: AnyPublisher<Result<Transaction, PendingTransactionProviderError>, Never> {
        completeTransactionSubject.eraseToAnyPublisher()
    }

    public init(session: WalletSession,
                transactionDataStore: TransactionDataStore,
                ercTokenDetector: ErcTokenDetector) {

        self.session = session
        self.transactionDataStore = transactionDataStore
        self.ercTokenDetector = ercTokenDetector
    }

    public func start() {
        transactionDataStore
            .initialOrNewTransactionsPublisher(forServer: session.server, transactionState: .pending)
            .sink { transactions in
                Task { [weak self] in
                    await self?.runPendingTransactionWatchers(transactions: transactions)
                }
            }.store(in: &cancelable)
    }

    public func cancelScheduler() {
        for each in store.values {
            each.cancel()
        }
    }

    public func resumeScheduler() {
        for each in store.values {
            each.restart()
        }
    }

    deinit {
        for each in self.store.values {
            each.cancel()
        }
    }

    private func runPendingTransactionWatchers(transactions: [Transaction]) {
        guard !session.config.development.isAutoFetchingDisabled else { return }
        for transaction in transactions {
            guard store[transaction.id] == nil else { continue }

            let provider = PendingTransactionSchedulerProvider(
                blockchainProvider: session.blockchainProvider,
                transaction: transaction,
                fetchPendingTransactionsQueue: fetchPendingTransactionsQueue)

            provider.responsePublisher
                .sink { response in
                    Task { [weak self] in
                        await self?.handle(response: response, transaction: transaction)
                    }
                }
                .store(in: &cancelable)

            let scheduler = Scheduler(provider: provider)
            scheduler.start()

            store[transaction.id] = scheduler
        }
    }

    private func handle(response: Result<EthereumTransaction, SessionTaskError>, transaction: Transaction) {
        switch response {
        case .success(let pendingTransaction):
            handle(transaction: transaction, pendingTransaction: pendingTransaction)
        case .failure(let error):
            handle(error: error, transaction: transaction)
        }
    }

    private func handle(transaction: Transaction, pendingTransaction: EthereumTransaction) {
        transactionDataStore.update(state: .completed, for: transaction.primaryKey, pendingTransaction: pendingTransaction)

        ercTokenDetector.detect(from: [transaction])

        Task { @MainActor in
            if let transaction = await transactionDataStore.transaction(withTransactionId: transaction.id, forServer: transaction.server) {
                completeTransactionSubject.send(.success(transaction))
            }

            await cancelScheduler(transaction: transaction)
        }
    }

    private func cancelScheduler(transaction: Transaction) {
        guard let scheduler = store[transaction.id] else { return }
        scheduler.cancel()
        store[transaction.id] = nil
    }

    private func handle(error: SessionTaskError, transaction: Transaction) {
        switch error {
        case .responseError(let error):
            // TODO: Think about the logic to handle pending transactions.
            //TODO we need to detect when a transaction is marked as failed by the node?
            switch error as? JSONRPCError {
            case .responseError:
                transactionDataStore.delete(transactions: [transaction])
                cancelScheduler(transaction: transaction)
            case .resultObjectParseError:
                Task { @MainActor in
                    guard await transactionDataStore.hasCompletedTransaction(withNonce: transaction.nonce, forServer: session.server) else { return }
                    transactionDataStore.delete(transactions: [transaction])
                    await cancelScheduler(transaction: transaction)
                }
                //The transaction might not be posted to this node yet (ie. it doesn't even think that this transaction is pending). Especially common if we post a transaction to Ethermine and fetch pending status through Etherscan
            case .responseNotFound, .errorObjectParseError, .unsupportedVersion, .unexpectedTypeObject, .missingBothResultAndError, .nonArrayResponse, .none:
                break
            }
        case .connectionError, .requestError:
            break
        }
    }
}

extension TransactionDataStore {
    func initialOrNewTransactionsPublisher(forServer server: RPCServer, transactionState: TransactionState) -> AnyPublisher<[Transaction], Never> {
        let predicate = TransactionDataStore.functional.transactionPredicate(server: server, transactionState: .pending)
        return transactionsChangeset(filter: .predicate(predicate), servers: [server])
            .map { changeset in
                switch changeset {
                case .initial(let transactions): return transactions
                case .update(let transactions, _, let insertions, _): return insertions.map { transactions[$0] }
                case .error: return []
                }
            }.filter { !$0.isEmpty }
            .eraseToAnyPublisher()
    }
}
