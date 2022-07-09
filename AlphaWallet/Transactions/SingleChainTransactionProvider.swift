// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

protocol SingleChainTransactionProviderDelegate: AnyObject {
    func didCompleteTransaction(transaction: TransactionInstance, in provider: SingleChainTransactionProvider)
}

protocol SingleChainTransactionProvider: AnyObject {
    var delegate: SingleChainTransactionProviderDelegate? { get set }

    init(session: WalletSession, analyticsCoordinator: AnalyticsCoordinator, transactionDataStore: TransactionDataStore, tokensDataStore: TokensDataStore, fetchLatestTransactionsQueue: OperationQueue, tokensFromTransactionsFetcher: TokensFromTransactionsFetcher)

    func start()
    func stopTimers()
    func runScheduledTimers()
    func fetch()
    func stop()
    func isServer(_ server: RPCServer) -> Bool
}
