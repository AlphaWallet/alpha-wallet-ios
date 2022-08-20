//
//  GetPendingTransaction.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.08.2022.
//

import Foundation
import APIKit
import JSONRPCKit
import PromiseKit
import Combine

final class GetPendingTransaction {
    private let server: RPCServer
    private let analytics: AnalyticsLogger

    init(server: RPCServer, analytics: AnalyticsLogger) {
        self.server = server
        self.analytics = analytics
    }

    func getPendingTransaction(hash: String) -> Promise<PendingTransaction?> {
        let request = GetTransactionRequest(hash: hash)
        return Session.send(EtherServiceRequest(server: server, batch: BatchFactory().create(request)), server: server, analytics: analytics)
    }

    //TODO log `Analytics.WebApiErrors.rpcNodeRateLimited` when appropriate too
    func getPendingTransaction(server: RPCServer, hash: String) -> AnyPublisher<PendingTransaction?, SessionTaskError> {
        let request = GetTransactionRequest(hash: hash)

        return Session
            .sendPublisher(EtherServiceRequest(server: server, batch: BatchFactory().create(request)), server: server)
            .eraseToAnyPublisher()
    }
}
