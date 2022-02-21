// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

protocol SingleChainTransactionDataCoordinatorDelegate: AnyObject {
    func handleUpdateItems(inCoordinator: SingleChainTransactionDataCoordinator, reloadImmediately: Bool)
}

protocol SingleChainTransactionDataCoordinator: Coordinator {
    init(session: WalletSession, storage: TransactionsStorage, keystore: Keystore, tokensDataStore: TokensDataStore, promptBackupCoordinator: PromptBackupCoordinator, onFetchLatestTransactionsQueue fetchLatestTransactionsQueue: OperationQueue)

    var delegate: SingleChainTransactionDataCoordinatorDelegate? { get set }

    var session: WalletSession { get }
    func start()
    func stopTimers()
    func runScheduledTimers()
    func fetch()
    func stop()
    func isServer(_ server: RPCServer) -> Bool
}
