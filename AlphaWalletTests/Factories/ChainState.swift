// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import AlphaWalletFoundation

extension ChainState {
    static func make(
        config: Config = .make(),
        analytics: AnalyticsLogger = FakeAnalyticsService(),
        server: RPCServer = .main
    ) -> ChainState {
        return ChainState(config: config, server: server, analytics: analytics)
    }
}
