// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet

class FakeClaimOrderCoordinator: ClaimOrderCoordinator {
    convenience init() {
        self.init(web3: Web3Swift(), server: .ropsten)
        startWeb3()
    }
}
