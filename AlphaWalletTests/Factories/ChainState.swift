// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import AlphaWalletFoundation

extension BlockNumberProvider {
    static func make(config: Config = .make(),
                     analytics: AnalyticsLogger = FakeAnalyticsService(),
                     server: RPCServer = .main) -> BlockNumberProvider {

        let blockchainProvider = RpcBlockchainProvider(
            server: server,
            rpcRequestProvider: BatchSupportableRpcRequestDispatcher.make(server: server),
            analytics: analytics,
            params: BlockchainParams.defaultParams(for: server))

        return BlockNumberProvider(storage: config, blockchainProvider: blockchainProvider)
    }
}

extension BatchSupportableRpcRequestDispatcher {
    static func make(server: RPCServer) -> BatchSupportableRpcRequestDispatcher {

        let transporter = HttpRpcRequestTransporter(
            server: server,
            rpcHttpParams: .init(rpcUrls: [server.rpcURL], headers: server.rpcHeaders),
            networkService: FakeRpcNetworkService(),
            analytics: FakeAnalyticsService())

        return BatchSupportableRpcRequestDispatcher(transporter: transporter, policy: .noBatching)
    }
}
