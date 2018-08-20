// Copyright © 2018 Stormbird PTE. LTD.

import XCTest
@testable import Trust
import Foundation

class TokenObjectTest: XCTestCase {
    func testCheckNonZeroBalance() {
        XCTAssertFalse(isNonZeroBalance(Constants.nullTicket))
    }
}
