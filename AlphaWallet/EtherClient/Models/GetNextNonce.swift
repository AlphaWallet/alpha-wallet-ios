// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import APIKit
import JSONRPCKit
import PromiseKit

class GetNextNonce {
    private let rpcURL: URL
    private let wallet: AlphaWallet.Address

    init(server: RPCServer, wallet: AlphaWallet.Address) {
        self.rpcURL = server.rpcURL
        self.wallet = wallet
    }

    init(rpcURL: URL, wallet: AlphaWallet.Address) {
        self.rpcURL = rpcURL
        self.wallet = wallet
    }

    func promise() -> Promise<Int> {
        let request = EtherServiceRequest(rpcURL: rpcURL, batch: BatchFactory().create(GetTransactionCountRequest(address: wallet, state: "pending")))
        return Session.send(request)
    }
}
