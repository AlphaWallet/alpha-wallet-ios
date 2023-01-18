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
    private let analytics: AnalyticsLogger

    public convenience init(server: RPCServer, analytics: AnalyticsLogger) {
        self.init(rpcURL: server.rpcURL, rpcHeaders: server.rpcHeaders, server: server, analytics: analytics)
    }

    public init(rpcURL: URL, rpcHeaders: [String: String], server: RPCServer, analytics: AnalyticsLogger) {
        self.rpcURL = rpcURL
        self.rpcHeaders = rpcHeaders
        self.server = server
        self.analytics = analytics
    }

    public func getNextNonce(wallet: AlphaWallet.Address) -> Promise<Int> {
        let request = EtherServiceRequest(rpcURL: rpcURL, rpcHeaders: rpcHeaders, batch: BatchFactory().create(GetTransactionCountRequest(address: wallet, state: "pending")))
        return APIKitSession.send(request, server: server, analytics: analytics)
    }
}

import Combine

public class GetChainId {
    private let analytics: AnalyticsLogger

    public init(analytics: AnalyticsLogger) {
        self.analytics = analytics
    }

    public func getChainId(server: RPCServer) -> AnyPublisher<Int, SessionTaskError> {
        let request = ChainIdRequest()
        return APIKitSession.sendPublisher(EtherServiceRequest(server: server, batch: BatchFactory().create(request)), server: server, analytics: analytics)
    }
}
