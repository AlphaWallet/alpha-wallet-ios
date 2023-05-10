// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

enum TransactionsSource {
    case etherscan(apiKey: String?, apiUrl: URL)
    case blockscout(apiKey: String?, apiUrl: URL)
    case covalent(apiKey: String?)
    case oklink(apiKey: String?)
    case unknown
}

public protocol SingleChainTransactionProvider: AnyObject {
    func start()
    func stopTimers()
    func runScheduledTimers()
    func stop()
    func isServer(_ server: RPCServer) -> Bool
}
