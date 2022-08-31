// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

public protocol SingleChainTransactionProviderDelegate: AnyObject {
    func didCompleteTransaction(transaction: TransactionInstance, in provider: SingleChainTransactionProvider)
}

public protocol SingleChainTransactionProvider: AnyObject {
    var delegate: SingleChainTransactionProviderDelegate? { get set }

    init(session: WalletSession, analytics: AnalyticsLogger, transactionDataStore: TransactionDataStore, tokensService: TokenProvidable, fetchLatestTransactionsQueue: OperationQueue, tokensFromTransactionsFetcher: TokensFromTransactionsFetcher)

    func start()
    func stopTimers()
    func runScheduledTimers()
    func fetch()
    func stop()
    func isServer(_ server: RPCServer) -> Bool
}
