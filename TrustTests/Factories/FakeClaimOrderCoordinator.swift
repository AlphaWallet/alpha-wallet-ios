// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import Trust

class FakeClaimOrderCoordinator: ClaimOrderCoordinator {
    convenience init() {
        self.init(web3: Web3Swift())
        startWeb3()
    }
}
