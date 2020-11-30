// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import APIKit
import JSONRPCKit
import PromiseKit

class GetNextNonce {
    let server: RPCServer
    let wallet: AlphaWallet.Address

    init(server: RPCServer, wallet: AlphaWallet.Address) {
        self.server = server
        self.wallet = wallet
    }

    func promise() -> Promise<Int> {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(GetTransactionCountRequest(address: wallet, state: "pending")))
        return Promise { seal in
            Session.send(request) { result in
                switch result {
                case .success(let count):
                    seal.fulfill(count)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }
}