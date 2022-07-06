// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import APIKit
import JSONRPCKit
import PromiseKit

class GetNextNonce {
    private let rpcURL: URL
    private let wallet: AlphaWallet.Address
    private let analyticsCoordinator: AnalyticsCoordinator

    init(server: RPCServer, wallet: AlphaWallet.Address, analyticsCoordinator: AnalyticsCoordinator) {
        self.rpcURL = server.rpcURL
        self.wallet = wallet
        self.analyticsCoordinator = analyticsCoordinator
    }

    init(rpcURL: URL, wallet: AlphaWallet.Address, analyticsCoordinator: AnalyticsCoordinator) {
        self.rpcURL = rpcURL
        self.wallet = wallet
        self.analyticsCoordinator = analyticsCoordinator
    }

    func promise() -> Promise<Int> {
        let request = EtherServiceRequest(rpcURL: rpcURL, batch: BatchFactory().create(GetTransactionCountRequest(address: wallet, state: "pending")))
        return Session.send(request, analyticsCoordinator: analyticsCoordinator)
    }
}
