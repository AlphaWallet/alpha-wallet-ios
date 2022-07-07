//
//  PendingTransactionFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 04.04.2022.
//

import Foundation
import APIKit
import BigInt
import JSONRPCKit
import Combine

typealias PendingTransactionResponse = EtherServiceRequest<Batch1<GetTransactionRequest>>.Response
final class PendingTransactionFetcher {

    //TODO log `Analytics.WebApiErrors.rpcNodeRateLimited` when appropriate too
    func transaction(forServer server: RPCServer, id: String) -> AnyPublisher<PendingTransactionResponse, SessionTaskError> {
        let request = GetTransactionRequest(hash: id)

        return Session
            .sendPublisher(EtherServiceRequest(server: server, batch: BatchFactory().create(request)), server: server)
            .eraseToAnyPublisher()
    }
}
