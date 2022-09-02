// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import APIKit
import JSONRPCKit
import PromiseKit

public class GetNextNonce {
    //Important to store the RPC URL and headers, and not read from `server` because it might be overridden by a RPC node that supports private transactions
    private let rpcURL: URL
    private let rpcHeaders: [String: String]
    private let server: RPCServer
    private let wallet: AlphaWallet.Address
    private let analytics: AnalyticsLogger

    public convenience init(server: RPCServer, wallet: AlphaWallet.Address, analytics: AnalyticsLogger) {
        self.init(rpcURL: server.rpcURL, rpcHeaders: server.rpcHeaders, server: server, wallet: wallet, analytics: analytics)
    }

    public init(rpcURL: URL, rpcHeaders: [String: String], server: RPCServer, wallet: AlphaWallet.Address, analytics: AnalyticsLogger) {
        self.rpcURL = rpcURL
        self.rpcHeaders = rpcHeaders
        self.server = server
        self.wallet = wallet
        self.analytics = analytics
    }

    public func promise() -> Promise<Int> {
        let request = EtherServiceRequest(rpcURL: rpcURL, rpcHeaders: rpcHeaders, batch: BatchFactory().create(GetTransactionCountRequest(address: wallet, state: "pending")))
        return Session.send(request, server: server, analytics: analytics)
    }
}
