//
//  GetBlockNumber.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.08.2022.
//

import Foundation
import JSONRPCKit
import APIKit
import PromiseKit

public final class GetBlockNumber {
    private let server: RPCServer
    private let analytics: AnalyticsLogger

    public init(server: RPCServer, analytics: AnalyticsLogger) {
        self.server = server
        self.analytics = analytics
    }

    public func getBlockNumber() -> Promise<Int> {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(BlockNumberRequest()))
        return Session.send(request, server: server, analytics: analytics)
    }
}
