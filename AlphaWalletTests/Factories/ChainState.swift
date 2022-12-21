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
            account: .make(),
            nodeApiProvider: NodeRpcApiProvider.make(server: server),
            analytics: analytics,
            params: BlockchainParams.defaultParams(for: server))

        return BlockNumberProvider(storage: config, blockchainProvider: blockchainProvider)
    }
}

extension NodeRpcApiProvider {
    private static var rpcUrl: URL {
        URL(string: "http://google.com")!
    }

    static func make(server: RPCServer) -> NodeRpcApiProvider {
        return NodeRpcApiProvider(
            rpcApiProvider: BaseRpcApiProvider.make(),
            server: server,
            rpcHttpParams: .init(rpcUrls: [rpcUrl], headers: server.rpcHeaders))
    }
}
