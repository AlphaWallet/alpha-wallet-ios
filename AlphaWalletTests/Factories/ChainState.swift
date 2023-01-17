// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import AlphaWalletFoundation

extension BlockNumberProvider {
    static func make(
        config: Config = .make(),
        analytics: AnalyticsLogger = FakeAnalyticsService(),
        server: RPCServer = .main
    ) -> BlockNumberProvider {
        return BlockNumberProvider(storage: config, server: server, analytics: analytics)
    }
}
