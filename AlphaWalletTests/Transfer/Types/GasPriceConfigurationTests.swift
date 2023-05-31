// Copyright SIX DAY LLC. All rights reserved.

@testable import AlphaWallet
import AlphaWalletFoundation
import BigInt
import XCTest

class GasPriceConfigurationTests: XCTestCase {
    func testDefault() {
        XCTAssertEqual(BigUInt(9000000000), GasPriceConfiguration.defaultPrice)
        XCTAssertEqual(BigUInt(1000000000), GasPriceConfiguration.minPrice)
        XCTAssertEqual(BigUInt(700000000000), GasPriceConfiguration.maxPrice)
    }
}
