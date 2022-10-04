// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import AlphaWalletFoundation

class FakeGetEthBalance: GetEthBalance {
    convenience init() {
        self.init(forServer: .main, analytics: FakeAnalyticsService())
    }
}
