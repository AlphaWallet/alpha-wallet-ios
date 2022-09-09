// Copyright © 2022 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet
@testable import AlphaWalletFoundation

class ChainIdTests: XCTestCase {
    func testLargeChainIdDisplay() {
        XCTAssertEqual(R.string.localizable.chainIDWithPrefix(RPCServer.palm.chainID), "Chain ID: 11,297,108,109")
    }
}
