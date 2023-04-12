// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import BigInt
import AlphaWalletFoundation

class TransactionConfiguratorTests: XCTestCase {
    func testAdjustGasPrice() {
        let gasPrice = BigUInt(1000000000)
        let analytics = FakeAnalyticsService()
        let configurator = TransactionConfigurator(
            session: .make(),
            analytics: analytics,
            transaction: .make(gasPrice: .legacy(gasPrice: gasPrice)),
            networkService: FakeNetworkService(),
            tokensService: WalletDataProcessingPipeline.make(wallet: .make(), server: .main).pipeline,
            configuration: .sendFungiblesTransaction(confirmType: .signThenSend))

        XCTAssertEqual(gasPrice, configurator.gasPriceEstimator.gasPrice.value.max)
    }

    func testMinGasPrice() {
        let analytics = FakeAnalyticsService()
        let configurator = TransactionConfigurator(
            session: .make(),
            analytics: analytics,
            transaction: .make(gasPrice: .legacy(gasPrice: BigUInt(1000000000))),
            networkService: FakeNetworkService(),
            tokensService: WalletDataProcessingPipeline.make(wallet: .make(), server: .main).pipeline,
            configuration: .sendFungiblesTransaction(confirmType: .signThenSend))

        XCTAssertEqual(GasPriceConfiguration.minPrice, configurator.gasPriceEstimator.gasPrice.value.max)
    }

    func testMaxGasPrice() {
        let analytics = FakeAnalyticsService()
        let configurator = TransactionConfigurator(
            session: .make(),
            analytics: analytics,
            transaction: .make(gasPrice: .legacy(gasPrice: BigUInt(990000000000))),
            networkService: FakeNetworkService(),
            tokensService: WalletDataProcessingPipeline.make(wallet: .make(), server: .main).pipeline,
            configuration: .sendFungiblesTransaction(confirmType: .signThenSend))

        XCTAssertEqual(GasPriceConfiguration.maxPrice, configurator.gasPriceEstimator.gasPrice.value.max)
    }

    func testSendEtherGasPriceAndLimit() {
        let analytics = FakeAnalyticsService()
        let configurator = TransactionConfigurator(
            session: .make(),
            analytics: analytics,
            transaction: .make(gasLimit: nil, gasPrice: nil),
            networkService: FakeNetworkService(),
            tokensService: WalletDataProcessingPipeline.make(wallet: .make(), server: .main).pipeline,
            configuration: .sendFungiblesTransaction(confirmType: .signThenSend))
        XCTAssertEqual(BigUInt(GasPriceConfiguration.defaultPrice), configurator.gasPriceEstimator.gasPrice.value.max)
        //gas limit is always 21k for native ether transfers
        XCTAssertEqual(BigUInt(21000), configurator.gasLimit.value)
    }
}
