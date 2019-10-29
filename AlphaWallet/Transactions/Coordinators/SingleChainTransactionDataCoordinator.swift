// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

protocol SingleChainTransactionDataCoordinatorDelegate: class {
    func handleUpdateItems(inCoordinator: SingleChainTransactionDataCoordinator)
}

protocol SingleChainTransactionDataCoordinator: Coordinator {
    init(session: WalletSession, storage: TransactionsStorage, keystore: Keystore, tokensStorage: TokensDataStore, promptBackupCoordinator: PromptBackupCoordinator, onFetchLatestTransactionsQueue fetchLatestTransactionsQueue: OperationQueue)

    var delegate: SingleChainTransactionDataCoordinatorDelegate? { get set }

    func start()
    func stopTimers()
    func runScheduledTimers()
    func fetch()
    func stop()
    func isServer(_ server: RPCServer) -> Bool
}
