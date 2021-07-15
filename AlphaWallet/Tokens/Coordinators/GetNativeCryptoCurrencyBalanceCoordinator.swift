// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import JSONRPCKit
import APIKit
import Result
import web3swift
import PromiseKit

protocol CallbackQueueProvider {
    var queue: DispatchQueue? { get }
}

extension CallbackQueueProvider {
    var callbackQueue: CallbackQueue? {
        if let value = queue {
            return .dispatchQueue(value)
        }
        return nil
    }
}

class GetNativeCryptoCurrencyBalanceCoordinator: CallbackQueueProvider {
    let server: RPCServer
    internal let queue: DispatchQueue?
    
    init(forServer server: RPCServer, queue: DispatchQueue? = nil) {
        self.server = server
        self.queue = queue
    }

    func getBalance(
        for address: AlphaWallet.Address,
        completion: @escaping (ResultResult<Balance, AnyError>.t) -> Void
    ) {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(BalanceRequest(address: address)))
        firstly {
            Session.send(request, callbackQueue: callbackQueue)
        }.done(on: queue, {
            completion(.success($0))
        }).catch(on: queue, {
            completion(.failure(AnyError($0)))
        })
    }
}
