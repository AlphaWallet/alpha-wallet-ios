// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import JSONRPCKit
import APIKit
import PromiseKit

open class GetNativeCryptoCurrencyBalance {
    private let server: RPCServer
    private let analytics: AnalyticsLogger
    private let queue: DispatchQueue?

    public init(forServer server: RPCServer, analytics: AnalyticsLogger, queue: DispatchQueue? = nil) {
        self.server = server
        self.analytics = analytics
        self.queue = queue
    }

    public func getBalance(for address: AlphaWallet.Address) -> Promise<Balance> {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(BalanceRequest(address: address)))
        return Session.send(request, server: server, analytics: analytics, callbackQueue: queue.flatMap { .dispatchQueue($0) })
    }
}
