// Copyright SIX DAY LLC. All rights reserved.

@testable import AlphaWallet
import AlphaWalletFoundation
import Foundation

extension BlockNumberProvider {
    static func make(
        config: Config = .make(),
        analytics: AnalyticsLogger = FakeAnalyticsService(),
        server: RPCServer = .main
    ) -> BlockNumberProvider {
        let blockchainProvider = RpcBlockchainProvider(server: server, analytics: analytics, params: .defaultParams(for: server))
        return BlockNumberProvider(storage: config, blockchainProvider: blockchainProvider)
    }
}
