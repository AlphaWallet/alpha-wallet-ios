// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import BigInt

class TransactionConfiguratorTests: XCTestCase {
    func testAdjustGasPrice() {
        let gasPrice = BigInt(1000000000)
        let configurator = TransactionConfigurator(session: .make(), transaction: .make(gasPrice: gasPrice))
        XCTAssertEqual(gasPrice, configurator.customConfiguration.gasPrice)
    }

    func testMinGasPrice() {
        let configurator = TransactionConfigurator(session: .make(), transaction: .make(gasPrice: BigInt(1)))
        XCTAssertEqual(GasPriceConfiguration.minPrice, configurator.customConfiguration.gasPrice)
    }

    func testMaxGasPrice() {
        let configurator = TransactionConfigurator(session: .make(), transaction: .make(gasPrice: BigInt(990000000000)))
        XCTAssertEqual(GasPriceConfiguration.maxPrice, configurator.customConfiguration.gasPrice)
    }

    func testSendEtherGasPriceAndLimit() {
        let configurator = TransactionConfigurator(session: .make(), transaction: .make(gasLimit: nil, gasPrice: nil))
        XCTAssertEqual(BigInt(GasPriceConfiguration.defaultPrice), configurator.customConfiguration.gasPrice)
        //gas limit is always 21k for native ether transfers
        XCTAssertEqual(BigInt(21000), configurator.customConfiguration.gasLimit)
    }
}
