// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import BigInt

class GasPriceConfigurationTests: XCTestCase {
    
    func testDefault() {
        XCTAssertEqual(BigInt(90000), GasPriceConfiguration.default)
        XCTAssertEqual(BigInt(21000), GasPriceConfiguration.min)
        XCTAssertEqual(BigInt(4712388), GasPriceConfiguration.maxGas)
    }
}
