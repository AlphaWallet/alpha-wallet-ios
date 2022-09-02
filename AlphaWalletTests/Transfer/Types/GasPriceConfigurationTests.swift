// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import BigInt
import AlphaWalletFoundation

class GasPriceConfigurationTests: XCTestCase {

    func testDefault() {
        XCTAssertEqual(BigInt(9000000000), GasPriceConfiguration.defaultPrice)
        XCTAssertEqual(BigInt(1000000000), GasPriceConfiguration.minPrice)
        XCTAssertEqual(BigInt(700000000000), GasPriceConfiguration.maxPrice)
    }
}
