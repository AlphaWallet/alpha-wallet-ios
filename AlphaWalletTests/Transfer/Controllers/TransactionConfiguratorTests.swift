// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import BigInt
import AlphaWalletFoundation

class TransactionConfiguratorTests: XCTestCase {
    func testAdjustGasPrice() throws {
        let gasPrice = BigInt(1000000000)
        let analytics = FakeAnalyticsService()
        let configurator = try TransactionConfigurator(session: .make(), analytics: analytics, transaction: .make(gasPrice: gasPrice))
        XCTAssertEqual(gasPrice, configurator.currentConfiguration.gasPrice)
    }

    func testMinGasPrice() throws {
        let analytics = FakeAnalyticsService()
        let configurator = try TransactionConfigurator(session: .make(), analytics: analytics, transaction: .make(gasPrice: BigInt(1)))
        XCTAssertEqual(GasPriceConfiguration.minPrice, configurator.currentConfiguration.gasPrice)
    }

    func testMaxGasPrice() throws {
        let analytics = FakeAnalyticsService()
        let configurator = try TransactionConfigurator(session: .make(), analytics: analytics, transaction: .make(gasPrice: BigInt(990000000000)))
        XCTAssertEqual(GasPriceConfiguration.maxPrice, configurator.currentConfiguration.gasPrice)
    }

    func testSendEtherGasPriceAndLimit() throws {
        let analytics = FakeAnalyticsService()
        let configurator = try TransactionConfigurator(session: .make(), analytics: analytics, transaction: .make(gasLimit: nil, gasPrice: nil))
        XCTAssertEqual(BigInt(GasPriceConfiguration.defaultPrice), configurator.currentConfiguration.gasPrice)
        //gas limit is always 21k for native ether transfers
        XCTAssertEqual(BigInt(21000), configurator.currentConfiguration.gasLimit)
    }
}
