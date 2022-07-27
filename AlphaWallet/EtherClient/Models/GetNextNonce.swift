// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import APIKit
import JSONRPCKit
import PromiseKit

class GetNextNonce {
    //Important to store the RPC URL and headers, and not read from `server` because it might be overridden by a RPC node that supports private transactions
    private let rpcURL: URL
    private let rpcHeaders: [String: String]
    private let server: RPCServer
    private let wallet: AlphaWallet.Address
    private let analyticsCoordinator: AnalyticsCoordinator

    convenience init(server: RPCServer, wallet: AlphaWallet.Address, analyticsCoordinator: AnalyticsCoordinator) {
        self.init(rpcURL: server.rpcURL, rpcHeaders: server.rpcHeaders, server: server, wallet: wallet, analyticsCoordinator: analyticsCoordinator)
    }

    init(rpcURL: URL, rpcHeaders: [String: String], server: RPCServer, wallet: AlphaWallet.Address, analyticsCoordinator: AnalyticsCoordinator) {
        self.rpcURL = rpcURL
        self.rpcHeaders = rpcHeaders
        self.server = server
        self.wallet = wallet
        self.analyticsCoordinator = analyticsCoordinator
    }

    func promise() -> Promise<Int> {
        let request = EtherServiceRequest(rpcURL: rpcURL, rpcHeaders: rpcHeaders, batch: BatchFactory().create(GetTransactionCountRequest(address: wallet, state: "pending")))
        return Session.send(request, server: server, analyticsCoordinator: analyticsCoordinator)
    }
}
