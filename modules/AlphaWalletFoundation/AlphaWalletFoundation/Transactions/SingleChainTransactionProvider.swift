// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

public protocol SingleChainTransactionProviderDelegate: AnyObject {
    func didCompleteTransaction(transaction: TransactionInstance, in provider: SingleChainTransactionProvider)
}

enum TransactionsSource {
    case etherscan
    case covalent
}

public protocol SingleChainTransactionProvider: AnyObject {
    var delegate: SingleChainTransactionProviderDelegate? { get set }

    func start()
    func stopTimers()
    func runScheduledTimers()
    func fetch()
    func stop()
    func isServer(_ server: RPCServer) -> Bool
}
