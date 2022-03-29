// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import Combine

enum TransactionError: Error {
    case failedToFetch
}

class TransactionsService {
    let transactionDataStore: TransactionDataStore
    private let sessions: ServerDictionary<WalletSession>
    private let tokensDataStore: TokensDataStore
    private var providers: [SingleChainTransactionProvider] = []
    private var config: Config { return sessions.anyValue.config }
    private let fetchLatestTransactionsQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Fetch Latest Transactions"
        //A limit is important for many reasons. One of which is Etherscan has a rate limit of 5 calls/sec/IP address according to https://etherscan.io/apis
        queue.maxConcurrentOperationCount = 3
        return queue
    }()

    var transactionsChangesetPublisher: AnyPublisher<[TransactionInstance], Never> {
        let servers = sessions.values.map { $0.server }
        return transactionDataStore
            .transactionsChangesetPublisher(forFilter: .all, servers: servers)
            .map { change -> [TransactionInstance] in
                switch change {
                case .initial(let transactions):
                    return Array(transactions).map { TransactionInstance(transaction: $0) }
                case .update(let transactions, _, _, _):
                    return Array(transactions).map { TransactionInstance(transaction: $0) }
                case .error:
                    return []
                }
            }
            .eraseToAnyPublisher()
    }

    init(sessions: ServerDictionary<WalletSession>, transactionDataStore: TransactionDataStore, tokensDataStore: TokensDataStore ) {
        self.sessions = sessions
        self.transactionDataStore = transactionDataStore
        self.tokensDataStore = tokensDataStore

        setupSingleChainTransactionProviders()
        NotificationCenter.default.addObserver(self, selector: #selector(stopTimers), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(restartTimers), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    private func setupSingleChainTransactionProviders() {
        providers = sessions.values.map { each in
            let providerType = each.server.transactionProviderType
            return providerType.init(session: each, transactionDataStore: transactionDataStore, tokensDataStore: tokensDataStore, fetchLatestTransactionsQueue: fetchLatestTransactionsQueue)
        }
    }

    func start() {
        for each in providers {
            each.start()
        }
    }

    @objc private func stopTimers() {
        for each in providers {
            each.stopTimers()
        }
    }

    @objc private func restartTimers() {
        guard !config.development.isAutoFetchingDisabled else { return }

        for each in providers {
            each.runScheduledTimers()
        }
    }

    func fetch() {
        guard !config.development.isAutoFetchingDisabled else { return }

        for each in providers {
            each.fetch()
        }
    }

    func transaction(withTransactionId transactionId: String, forServer server: RPCServer) -> TransactionInstance? {
        transactionDataStore.transaction(withTransactionId: transactionId, forServer: server)
    }

    func addSentTransaction(_ transaction: SentTransaction) {
        let session = sessions[transaction.original.server]
        
        TransactionDataStore.pendingTransactionsInformation[transaction.id] = (server: transaction.original.server, data: transaction.original.data, transactionType: transaction.original.transactionType, gasPrice: transaction.original.gasPrice)
        let transaction = Transaction.from(from: session.account.address, transaction: transaction, tokensDataStore: tokensDataStore, server: transaction.original.server)
        transactionDataStore.add(transactions: [transaction])
    }

    func stop() {
        for each in providers {
            each.stop()
        }
    }
}
