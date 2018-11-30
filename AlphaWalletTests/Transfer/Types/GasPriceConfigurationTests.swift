// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import BigInt

class GasPriceConfigurationTests: XCTestCase {
    
    func testDefault() {
        XCTAssertEqual(BigInt(90000), GasPriceConfiguration.defaultPrice)
        XCTAssertEqual(BigInt(21000), GasPriceConfiguration.minPrice)
        XCTAssertEqual(BigInt(4712388), GasPriceConfiguration.maxPrice)
    }
}
