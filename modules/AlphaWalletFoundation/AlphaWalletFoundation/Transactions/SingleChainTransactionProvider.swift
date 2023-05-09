// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

enum TransactionsSource {
    case etherscan(apiKey: String?, url: URL)
    case blockscout(apiKey: String?, url: URL)
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
