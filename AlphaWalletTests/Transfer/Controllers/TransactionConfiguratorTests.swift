// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import BigInt

class TransactionConfiguratorTests: XCTestCase {
    func testAdjustGasPrice() throws {
        let gasPrice = BigInt(1000000000)
        let configurator = try TransactionConfigurator(session: .make(), transaction: .make(gasPrice: gasPrice))
        XCTAssertEqual(gasPrice, configurator.currentConfiguration.gasPrice)
    }

    func testMinGasPrice() throws {
        let configurator = try TransactionConfigurator(session: .make(), transaction: .make(gasPrice: BigInt(1)))
        XCTAssertEqual(GasPriceConfiguration.minPrice, configurator.currentConfiguration.gasPrice)
    }

    func testMaxGasPrice() throws {
        let configurator = try TransactionConfigurator(session: .make(), transaction: .make(gasPrice: BigInt(990000000000)))
        XCTAssertEqual(GasPriceConfiguration.maxPrice, configurator.currentConfiguration.gasPrice)
    }

    func testSendEtherGasPriceAndLimit() throws {
        let configurator = try TransactionConfigurator(session: .make(), transaction: .make(gasLimit: nil, gasPrice: nil))
        XCTAssertEqual(BigInt(GasPriceConfiguration.defaultPrice), configurator.currentConfiguration.gasPrice)
        //gas limit is always 21k for native ether transfers
        XCTAssertEqual(BigInt(21000), configurator.currentConfiguration.gasLimit)
    }
}
