// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

enum TransactionsSource {
    case etherscan
    case covalent
}

public protocol SingleChainTransactionProvider: AnyObject {
    func start()
    func stopTimers()
    func runScheduledTimers()
    func fetch()
    func stop()
    func isServer(_ server: RPCServer) -> Bool
}
