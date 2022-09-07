//
//  PendingTransactionProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.04.2022.
//

import Foundation
import APIKit
import BigInt
import JSONRPCKit
import PromiseKit
import Combine

final class PendingTransactionProvider {
    private let session: WalletSession
    private let transactionDataStore: TransactionDataStore
    private let tokensFromTransactionsFetcher: TokensFromTransactionsFetcher
    private let fetcher: GetPendingTransaction
    private var cancelable = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "com.PendingTransactionProvider.updateQueue")
    private let fetchPendingTransactionsQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Auto-update Pending Transactions"
        queue.maxConcurrentOperationCount = 5

        return queue
    }()

    private lazy var store: AtomicDictionary<String, SchedulerProtocol> = .init()

    init(session: WalletSession, transactionDataStore: TransactionDataStore, tokensFromTransactionsFetcher: TokensFromTransactionsFetcher, fetcher: GetPendingTransaction) {
        self.session = session
        self.transactionDataStore = transactionDataStore
        self.tokensFromTransactionsFetcher = tokensFromTransactionsFetcher
        self.fetcher = fetcher
    }

    func start() {
        transactionDataStore
            .initialOrNewTransactionsPublisher(forServer: session.server, transactionState: .pending)
            .receive(on: queue)
            .sink { [weak self] transactions in
                self?.runPendingTransactionWatchers(transactions: transactions)
            }.store(in: &cancelable)
    }

    func cancelScheduler() {
        queue.async {
            for each in self.store.values {
                each.value.cancel()
            }
        }
    }

    func resumeScheduler() {
        queue.async {
            for each in self.store.values {
                each.value.resume()
            }
        }
    }

    deinit {
        for each in store.values {
            each.value.cancel()
        } 
    }

    private func runPendingTransactionWatchers(transactions: [TransactionInstance]) {
        for each in transactions {
            if store[each.id] != nil {
                //no-op
            } else {
                let provider = PendingTransactionSchedulerProvider(fetcher: fetcher, transaction: each, fetchPendingTransactionsQueue: fetchPendingTransactionsQueue)
                provider.delegate = self
                let scheduler = Scheduler(provider: provider)

                scheduler.start()

                store[each.id] = scheduler
            }
        }
    }

    private func didReceiveValue(transaction: TransactionInstance, pendingTransaction: PendingTransaction) {
        transactionDataStore.update(state: .completed, for: transaction.primaryKey, withPendingTransaction: pendingTransaction)
        tokensFromTransactionsFetcher.extractNewTokens(from: [transaction])

        cancelScheduler(transaction: transaction)
    }

    private func cancelScheduler(transaction: TransactionInstance) {
        guard let scheduler = store[transaction.id] else { return }
        scheduler.cancel()
        store[transaction.id] = nil
    }

    private func didReceiveError(error: Covalent.CovalentError, forTransaction transaction: TransactionInstance) {
        switch error {
        case .jsonDecodeFailure, .requestFailure:
            break
        case .sessionError(let error):
            switch error {
            case .responseError(let error):
                // TODO: Think about the logic to handle pending transactions.
                //TODO we need to detect when a transaction is marked as failed by the node?
                switch error as? JSONRPCError {
                case .responseError:
                    transactionDataStore.delete(transactions: [transaction])
                    cancelScheduler(transaction: transaction)
                case .resultObjectParseError:
                    guard transactionDataStore.hasCompletedTransaction(withNonce: transaction.nonce, forServer: session.server) else { return }
                    transactionDataStore.delete(transactions: [transaction])
                    cancelScheduler(transaction: transaction)
                    //The transaction might not be posted to this node yet (ie. it doesn't even think that this transaction is pending). Especially common if we post a transaction to Ethermine and fetch pending status through Etherscan
                case .responseNotFound, .errorObjectParseError, .unsupportedVersion, .unexpectedTypeObject, .missingBothResultAndError, .nonArrayResponse, .none:
                    break
                }
            case .connectionError, .requestError:
                break
            }
        }
    }
}

extension PendingTransactionProvider: PendingTransactionSchedulerProviderDelegate {
    func didReceiveResponse(_ response: Swift.Result<PendingTransaction, Covalent.CovalentError>, in provider: PendingTransactionSchedulerProvider) {
        switch response {
        case .success(let pendingTransaction):
            didReceiveValue(transaction: provider.transaction, pendingTransaction: pendingTransaction)
        case .failure(let error):
            didReceiveError(error: error, forTransaction: provider.transaction)
        }
    }
}

extension TransactionDataStore {
    func initialOrNewTransactionsPublisher(forServer server: RPCServer, transactionState: TransactionState) -> AnyPublisher<[TransactionInstance], Never> {
        let predicate = TransactionDataStore.functional.transactionPredicate(server: server, transactionState: .pending)
        return transactionsChangeset(forFilter: .predicate(predicate), servers: [server])
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
