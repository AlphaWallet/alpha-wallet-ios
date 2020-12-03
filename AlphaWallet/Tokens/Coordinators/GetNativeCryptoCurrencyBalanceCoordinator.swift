// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import JSONRPCKit
import APIKit
import Result
import web3swift
import PromiseKit

class GetNativeCryptoCurrencyBalanceCoordinator {
    let server: RPCServer

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getBalance(
        for address: AlphaWallet.Address,
        completion: @escaping (ResultResult<Balance, AnyError>.t) -> Void
    ) {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(BalanceRequest(address: address)))
        firstly {
            Session.send(request)
        }.done {
            completion(.success($0))
        }.catch {
            completion(.failure(AnyError($0)))
        }
    }
}
