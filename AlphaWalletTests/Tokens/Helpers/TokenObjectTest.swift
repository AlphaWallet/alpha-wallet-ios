// Copyright © 2018 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet
import Foundation

class TokenObjectTest: XCTestCase {
    func testCheckNonZeroBalance() {
        XCTAssertFalse(isNonZeroBalance(Constants.nullTokenId, tokenType: .erc875))
    }
}
