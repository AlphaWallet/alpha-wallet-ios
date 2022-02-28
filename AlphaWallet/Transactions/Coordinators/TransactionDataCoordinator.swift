// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

enum TransactionError: Error {
    case failedToFetch
}

protocol TransactionDataCoordinatorDelegate: AnyObject {
    func didUpdate(result: ResultResult<[TransactionInstance], TransactionError>.t, reloadImmediately: Bool)
}

class TransactionDataCoordinator: Coordinator {
    static let deleteMissingInternalSeconds: Double = 60.0
    static let delayedTransactionInternalSeconds: Double = 60.0

    private let transactionCollection: TransactionCollection
    private let sessions: ServerDictionary<WalletSession>
    private let keystore: Keystore
    private let tokensDataStore: TokensDataStore
    private let promptBackupCoordinator: PromptBackupCoordinator
    private var singleChainTransactionDataCoordinators: [SingleChainTransactionDataCoordinator] {
        return coordinators.compactMap { $0 as? SingleChainTransactionDataCoordinator }
    }
    private var config: Config {
        return sessions.anyValue.config
    }
    private let fetchLatestTransactionsQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Fetch Latest Transactions"
        //A limit is important for many reasons. One of which is Etherscan has a rate limit of 5 calls/sec/IP address according to https://etherscan.io/apis
        queue.maxConcurrentOperationCount = 3
        return queue
    }()

    var coordinators: [Coordinator] = []

    init(
            sessions: ServerDictionary<WalletSession>,
            transactionCollection: TransactionCollection,
            keystore: Keystore,
            tokensDataStore: TokensDataStore,
            promptBackupCoordinator: PromptBackupCoordinator
    ) {
        self.sessions = sessions
        self.transactionCollection = transactionCollection
        self.keystore = keystore
        self.tokensDataStore = tokensDataStore
        self.promptBackupCoordinator = promptBackupCoordinator
        setupSingleChainTransactionDataCoordinators()
        NotificationCenter.default.addObserver(self, selector: #selector(stopTimers), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(restartTimers), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    private func setupSingleChainTransactionDataCoordinators() {
        for each in transactionCollection.transactionsStorages {
            let server = each.server
            let session = sessions[server]
            let coordinatorType = server.transactionDataCoordinatorType
            let coordinator = coordinatorType.init(session: session, storage: each, keystore: keystore, tokensDataStore: tokensDataStore, promptBackupCoordinator: promptBackupCoordinator, onFetchLatestTransactionsQueue: fetchLatestTransactionsQueue)
            coordinator.delegate = self
            addCoordinator(coordinator)
        }
    }

    func start() {
        for each in singleChainTransactionDataCoordinators {
            each.start()
        }
    }

    @objc private func stopTimers() {
        for each in singleChainTransactionDataCoordinators {
            each.stopTimers()
        }
    }

    @objc private func restartTimers() {
        guard !config.development.isAutoFetchingDisabled else { return }

        for each in singleChainTransactionDataCoordinators {
            each.runScheduledTimers()
        }
    }

    func fetch() {
        guard !config.development.isAutoFetchingDisabled else { return }

        for each in singleChainTransactionDataCoordinators {
            each.fetch()
        }
    }

    func addSentTransaction(_ transaction: SentTransaction) {
        let session = sessions[transaction.original.server]
        TransactionsStorage.pendingTransactionsInformation[transaction.id] = (server: transaction.original.server, data: transaction.original.data, transactionType: transaction.original.transactionType, gasPrice: transaction.original.gasPrice)
        let transaction = Transaction.from(from: session.account.address, transaction: transaction, tokensDataStore: tokensDataStore, server: transaction.original.server)
        transactionCollection.add([transaction])
    }

    func stop() {
        for each in singleChainTransactionDataCoordinators {
            each.stop()
        }
    }

    private func singleChainTransactionDataCoordinator(forServer server: RPCServer) -> SingleChainTransactionDataCoordinator? {
        return singleChainTransactionDataCoordinators.first { $0.isServer(server) }
    }
}

extension TransactionDataCoordinator: SingleChainTransactionDataCoordinatorDelegate {
    func handleUpdateItems(inCoordinator: SingleChainTransactionDataCoordinator, reloadImmediately: Bool) {
        // no-op
    }
}
