// Copyright © 2018 Stormbird PTE. LTD.

import XCTest
@testable import Trust
import Foundation

class TokenObjectTest: XCTestCase {
    func testCheckNonZeroBalance() {
        XCTAssertFalse(isNonZeroBalance("0"))
        XCTAssertFalse(isNonZeroBalance("00"))
        XCTAssertTrue(isNonZeroBalance("1"))
    }
}
