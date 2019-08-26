// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import JSONRPCKit
import APIKit
import Result
import web3swift

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
        Session.send(request) { result in
            switch result {
            case .success(let balance):
                completion(.success(balance))
            case .failure(let error):
                completion(.failure(AnyError(error)))
            }
        }
    }
}
