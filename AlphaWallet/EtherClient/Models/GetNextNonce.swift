// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import APIKit
import JSONRPCKit
import PromiseKit

class GetNextNonce {
    //Important to store the RPC URL and not read `RPCServer.server` because it might be overridden by a RPC node that supports private transactions
    private let rpcURL: URL
    private let server: RPCServer
    private let wallet: AlphaWallet.Address
    private let analyticsCoordinator: AnalyticsCoordinator

    init(server: RPCServer, wallet: AlphaWallet.Address, analyticsCoordinator: AnalyticsCoordinator) {
        self.rpcURL = server.rpcURL
        self.server = server
        self.wallet = wallet
        self.analyticsCoordinator = analyticsCoordinator
    }

    init(rpcURL: URL, server: RPCServer, wallet: AlphaWallet.Address, analyticsCoordinator: AnalyticsCoordinator) {
        self.rpcURL = rpcURL
        self.server = server
        self.wallet = wallet
        self.analyticsCoordinator = analyticsCoordinator
    }

    func promise() -> Promise<Int> {
        let request = EtherServiceRequest(rpcURL: rpcURL, batch: BatchFactory().create(GetTransactionCountRequest(address: wallet, state: "pending")))
        return Session.send(request, server: server, analyticsCoordinator: analyticsCoordinator)
    }
}
