// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import BigInt

class TransactionConfiguratorTests: XCTestCase {

    func testDefault() {
        let configurator = TransactionConfigurator(session: .make(), account: .make(), transaction: .make(gasLimit: BigInt(90000), gasPrice: .none))

        XCTAssertEqual(GasPriceConfiguration.defaultPrice, configurator.configuration.gasPrice)
    }

    func testAdjustGasPrice() {
        let desiderGasPrice = BigInt(1000000000)
        let configurator = TransactionConfigurator(session: .make(), account: .make(), transaction: .make(gasPrice: desiderGasPrice))

        XCTAssertEqual(desiderGasPrice, configurator.configuration.gasPrice)
    }

    func testMinGasPrice() {
        let configurator = TransactionConfigurator(session: .make(), account: .make(), transaction: .make(gasPrice: BigInt(1)))

        XCTAssertEqual(GasPriceConfiguration.minPrice, configurator.configuration.gasPrice)
    }

    func testMaxGasPrice() {
        let configurator = TransactionConfigurator(session: .make(), account: .make(), transaction: .make(gasPrice: BigInt(990000000000)))

        XCTAssertEqual(GasPriceConfiguration.maxPrice, configurator.configuration.gasPrice)
    }

    func testLoadEtherConfiguration() {
        let configurator = TransactionConfigurator(session: .make(), account: .make(), transaction: .make(gasLimit: BigInt(50000), gasPrice: .none))

        configurator.start { _ in }

        XCTAssertEqual(BigInt(GasPriceConfiguration.defaultPrice), configurator.configuration.gasPrice)
        //gas limit is always 21k for native ether transfers
        XCTAssertEqual(BigInt(21000), configurator.configuration.gasLimit)
    }
}
