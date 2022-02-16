// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import JSONRPCKit
import APIKit
import Result
import web3swift
import PromiseKit

class GetNativeCryptoCurrencyBalanceCoordinator {
    private let server: RPCServer
    private let queue: DispatchQueue?
    
    init(forServer server: RPCServer, queue: DispatchQueue? = nil) {
        self.server = server
        self.queue = queue
    }

    func getBalance(for address: AlphaWallet.Address) -> Promise<Balance> {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(BalanceRequest(address: address)))
        return Session.send(request, callbackQueue: queue.flatMap { .dispatchQueue($0) })
    }
}
