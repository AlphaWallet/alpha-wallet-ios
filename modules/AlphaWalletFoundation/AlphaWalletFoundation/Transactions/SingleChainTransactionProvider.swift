// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

enum TransactionsSource {
    case etherscan
    case covalent(apiKey: String?)
    case oklink(apiKey: String?)
}

public protocol SingleChainTransactionProvider: AnyObject {
    func start()
    func stopTimers()
    func runScheduledTimers()
    func stop()
    func isServer(_ server: RPCServer) -> Bool
}
