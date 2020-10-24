// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

enum TransactionError: Error {
    case failedToFetch
}

protocol TransactionDataCoordinatorDelegate: class {
    func didUpdate(result: ResultResult<[Transaction], TransactionError>.t, reloadImmediately: Bool)
}

class TransactionDataCoordinator: Coordinator {
    static let deleteMissingInternalSeconds: Double = 60.0
    static let delayedTransactionInternalSeconds: Double = 60.0

    private let transactionCollection: TransactionCollection
    private let sessions: ServerDictionary<WalletSession>
    private let keystore: Keystore
    private let tokensStorages: ServerDictionary<TokensDataStore>
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

    weak var delegate: TransactionDataCoordinatorDelegate?
    //TODO we do away with the Transactions tab and use Activity tab, we can remove this `delegate2`
    weak var delegate2: TransactionDataCoordinatorDelegate?
    var coordinators: [Coordinator] = []

    init(
            sessions: ServerDictionary<WalletSession>,
            transactionCollection: TransactionCollection,
            keystore: Keystore,
            tokensStorages: ServerDictionary<TokensDataStore>,
            promptBackupCoordinator: PromptBackupCoordinator
    ) {
        self.sessions = sessions
        self.transactionCollection = transactionCollection
        self.keystore = keystore
        self.tokensStorages = tokensStorages
        self.promptBackupCoordinator = promptBackupCoordinator
        setupSingleChainTransactionDataCoordinators()
        NotificationCenter.default.addObserver(self, selector: #selector(stopTimers), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(restartTimers), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    private func setupSingleChainTransactionDataCoordinators() {
        for each in transactionCollection.transactionsStorages {
            let server = each.server
            let session = sessions[server]
            let tokensDataStore = tokensStorages[server]
            let coordinatorType = server.transactionDataCoordinatorType
            let coordinator = coordinatorType.init(session: session, storage: each, keystore: keystore, tokensStorage: tokensDataStore, promptBackupCoordinator: promptBackupCoordinator, onFetchLatestTransactionsQueue: fetchLatestTransactionsQueue)
            coordinator.delegate = self
            addCoordinator(coordinator)
        }
    }

    func start() {
        for each in singleChainTransactionDataCoordinators {
            each.start()
        }
        //Since start() is called at launch, and user don't see the Transactions tab immediately, we don't want it to block launching
        DispatchQueue.global().async {
            DispatchQueue.main.async { [weak self] in
                self?.handleUpdateItems(reloadImmediately: false)
            }
        }
    }

    @objc private func stopTimers() {
        for each in singleChainTransactionDataCoordinators {
            each.stopTimers()
        }
    }

    @objc private func restartTimers() {
        runScheduledTimers()
    }

    private func runScheduledTimers() {
        guard !config.isAutoFetchingDisabled else { return }
        for each in singleChainTransactionDataCoordinators {
            each.runScheduledTimers()
        }
    }

    func fetch() {
        guard !config.isAutoFetchingDisabled else { return }
        for each in singleChainTransactionDataCoordinators {
            each.fetch()
        }
    }

    func addSentTransaction(_ transaction: SentTransaction) {
        let session = sessions[transaction.original.server]

        let tokensDataStore = tokensStorages[transaction.original.server]
        let transaction = Transaction.from(from: session.account.address, transaction: transaction, tokensDataStore: tokensDataStore)
        transactionCollection.add([transaction])
        handleUpdateItems(reloadImmediately: true)
    }

    func stop() {
        for each in singleChainTransactionDataCoordinators {
            each.stop()
        }
    }

    private func singleChainTransactionDataCoordinator(forServer server: RPCServer) -> SingleChainTransactionDataCoordinator? {
        return singleChainTransactionDataCoordinators.first { $0.isServer(server) }
    }

    private func handleUpdateItems(reloadImmediately: Bool) {
        delegate?.didUpdate(result: .success(transactionCollection.objects), reloadImmediately: reloadImmediately)
        delegate2?.didUpdate(result: .success(transactionCollection.objects), reloadImmediately: reloadImmediately)
    }
}

extension TransactionDataCoordinator: SingleChainTransactionDataCoordinatorDelegate {
    func handleUpdateItems(inCoordinator: SingleChainTransactionDataCoordinator) {
        handleUpdateItems(reloadImmediately: false)
    }
}
