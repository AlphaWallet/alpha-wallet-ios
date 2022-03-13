// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

protocol SingleChainTransactionDataCoordinator: Coordinator {
    init(session: WalletSession, transactionDataStore: TransactionDataStore, keystore: Keystore, tokensDataStore: TokensDataStore, promptBackupCoordinator: PromptBackupCoordinator, onFetchLatestTransactionsQueue fetchLatestTransactionsQueue: OperationQueue)
    
    func start()
    func stopTimers()
    func runScheduledTimers()
    func fetch()
    func stop()
    func isServer(_ server: RPCServer) -> Bool
}
