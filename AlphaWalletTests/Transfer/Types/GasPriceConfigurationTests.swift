// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import BigInt
import AlphaWalletFoundation

class GasPriceConfigurationTests: XCTestCase {

    func testDefault() {
        XCTAssertEqual(BigUInt(9000000000), GasPriceConfiguration.defaultPrice)
        XCTAssertEqual(BigUInt(1000000000), GasPriceConfiguration.minPrice)
        XCTAssertEqual(BigUInt(700000000000), GasPriceConfiguration.maxPrice)
    }
}
