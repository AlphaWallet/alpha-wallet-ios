// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import APIKit
import JSONRPCKit

import Combine

public class GetChainId {
    private let analytics: AnalyticsLogger

    public init(analytics: AnalyticsLogger) {
        self.analytics = analytics
    }

    public func getChainId(server: RPCServer) -> AnyPublisher<Int, SessionTaskError> {
        let request = ChainIdRequest()
        return APIKitSession.sendPublisher(EtherServiceRequest(server: server, batch: BatchFactory().create(request)), server: server, analytics: analytics)
    }
}
