// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import JSONRPCKit
import PromiseKit

public final class EthCall {
    private let server: RPCServer
    private let analytics: AnalyticsLogger

    public init(server: RPCServer, analytics: AnalyticsLogger) {
        self.server = server
        self.analytics = analytics
    }

    public func ethCall(from: AlphaWallet.Address?, to: AlphaWallet.Address?, value: String?, data: String) -> Promise<String> {
        let request = EthCallRequest(from: from, to: to, value: value, data: data)
        return APIKitSession.send(EtherServiceRequest(server: server, batch: BatchFactory().create(request)), server: server, analytics: analytics)
    }
}
