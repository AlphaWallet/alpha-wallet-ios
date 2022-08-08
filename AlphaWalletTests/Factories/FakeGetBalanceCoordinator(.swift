// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet

class FakeGetBalanceCoordinator: GetNativeCryptoCurrencyBalance {
    convenience init() {
        self.init(forServer: .main, analytics: FakeAnalyticsService())
    }
}
