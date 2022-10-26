// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import JSONRPCKit
import APIKit
import PromiseKit

open class GetEthBalance {
    private let server: RPCServer
    private let analytics: AnalyticsLogger
    private var inFlightPromises: [String: Promise<Balance>] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.getEthBalance")

    public init(forServer server: RPCServer, analytics: AnalyticsLogger) {
        self.server = server
        self.analytics = analytics
    }

    public func getBalance(for address: AlphaWallet.Address) -> Promise<Balance> {
        firstly {
            .value(address)
        }.then(on: queue, { [weak self, queue, server, analytics] address -> Promise<Balance> in
            let key = address.eip55String
            
            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                let request = EtherServiceRequest(server: server, batch: BatchFactory().create(BalanceRequest(address: address)))
                let promise = firstly {
                    APIKitSession.send(request, server: server, analytics: analytics)
                }.ensure(on: queue, {
                    self?.inFlightPromises[key] = .none
                })

                self?.inFlightPromises[key] = promise

                return promise
            }
        })

    }
}
