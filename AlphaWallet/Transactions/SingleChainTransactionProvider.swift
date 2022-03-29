// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

protocol SingleChainTransactionProvider: AnyObject {
    init(session: WalletSession, transactionDataStore: TransactionDataStore, tokensDataStore: TokensDataStore, fetchLatestTransactionsQueue: OperationQueue)
    
    func start()
    func stopTimers()
    func runScheduledTimers()
    func fetch()
    func stop()
    func isServer(_ server: RPCServer) -> Bool
}
