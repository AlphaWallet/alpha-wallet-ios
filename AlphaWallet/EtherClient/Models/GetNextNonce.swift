// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import APIKit
import JSONRPCKit
import PromiseKit

class GetNextNonce {
    private let server: RPCServer
    private let wallet: AlphaWallet.Address

    init(server: RPCServer, wallet: AlphaWallet.Address) {
        self.server = server
        self.wallet = wallet
    }

    func promise() -> Promise<Int> {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(GetTransactionCountRequest(address: wallet, state: "pending")))
        return Session.send(request)
    }
}