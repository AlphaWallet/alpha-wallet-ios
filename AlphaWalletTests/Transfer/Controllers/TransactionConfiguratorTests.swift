// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import BigInt
import AlphaWalletFoundation

class TransactionConfiguratorTests: XCTestCase {
    func testAdjustGasPrice() {
        let gasPrice = GasPrice.legacy(gasPrice: BigUInt(1000000000))
        let configurator = TransactionConfigurator(
            session: .make(),
            transaction: .make(gasPrice: gasPrice),
            networkService: FakeNetworkService(),
            tokensService: WalletDataProcessingPipeline.make(wallet: .make(), server: .main).pipeline,
            configuration: .sendFungiblesTransaction(confirmType: .signThenSend))

        XCTAssertEqual(gasPrice, configurator.gasPriceEstimator.gasPrice.value)
    }

    func testMinGasPrice() {
        let configurator = TransactionConfigurator(
            session: .make(),
            transaction: .make(gasPrice: .legacy(gasPrice: BigUInt(1000000000))),
            networkService: FakeNetworkService(),
            tokensService: WalletDataProcessingPipeline.make(wallet: .make(), server: .main).pipeline,
            configuration: .sendFungiblesTransaction(confirmType: .signThenSend))

        XCTAssertEqual(GasPriceConfiguration.minPrice, configurator.gasPriceEstimator.gasPrice.value.max)
    }

    func testMaxGasPrice() {
        let configurator = TransactionConfigurator(
            session: .make(),
            transaction: .make(gasPrice: .legacy(gasPrice: BigUInt(990000000000))),
            networkService: FakeNetworkService(),
            tokensService: WalletDataProcessingPipeline.make(wallet: .make(), server: .main).pipeline,
            configuration: .sendFungiblesTransaction(confirmType: .signThenSend))

        XCTAssertEqual(GasPriceConfiguration.maxPrice, configurator.gasPriceEstimator.gasPrice.value.max)
    }

    func testSendEtherGasPriceAndLimit() {
        let configurator = TransactionConfigurator(
            session: .make(),
            transaction: .make(gasLimit: nil, gasPrice: nil),
            networkService: FakeNetworkService(),
            tokensService: WalletDataProcessingPipeline.make(wallet: .make(), server: .main).pipeline,
            configuration: .sendFungiblesTransaction(confirmType: .signThenSend))
        XCTAssertEqual(BigUInt(GasPriceConfiguration.defaultPrice), configurator.gasPriceEstimator.gasPrice.value.max)

        //gas limit is always 21k for native ether transfers
        XCTAssertEqual(BigUInt(21000), configurator.gasLimit.value)
    }
}
