// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet

class FakeGetBalanceCoordinator: GetNativeCryptoCurrencyBalanceCoordinator {
    convenience init() {
        self.init(forServer: .main)
    }
}
