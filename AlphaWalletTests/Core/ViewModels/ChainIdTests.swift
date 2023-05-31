// Copyright © 2022 Stormbird PTE. LTD.

@testable import AlphaWallet
@testable import AlphaWalletFoundation
import XCTest

class ChainIdTests: XCTestCase {
    func testLargeChainIdDisplay() {
        XCTAssertEqual(R.string.localizable.chainIDWithPrefix(RPCServer.palm.chainID), "Chain ID: 11,297,108,109")
    }
}
