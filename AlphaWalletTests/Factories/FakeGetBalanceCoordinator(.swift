// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet

class FakeGetBalanceCoordinator: GetBalanceCoordinator {
    convenience init() {
        self.init(forServer: .main)
    }
}
