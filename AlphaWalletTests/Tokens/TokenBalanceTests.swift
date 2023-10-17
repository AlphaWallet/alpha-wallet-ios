// Copyright © 2023 Stormbird PTE. LTD.

import UIKit
@testable import AlphaWallet
import XCTest
import BigInt
import Combine
import AlphaWalletFoundation

//Some of the expectations have `assertForOverFulfill = false` because for those cases we can't reliably know exactly how many times a publisher will emit
class TokenBalanceTests: XCTestCase {
    //Must not use store AnyCancellable as properties since we want to cancel them explicitly either in `sink()` or after waiting for the matching expectation. Otherwise the publisher can continue to fire and generate expected results that fail the expectations (especially asserting that a token is not-nil fails because the pipeline or objects used by the publisher is now nil)
    //private var cancelable = Set<AnyCancellable>()

    func testTokenViewModelChanges() async {
        //Don't share these among the test cases
        let coinTickersFetcher = CoinTickers.make()
        let currencyService: CurrencyService = .make()
        let dep = WalletDataProcessingPipeline.make(wallet: .make(), server: .main, coinTickersFetcher: coinTickersFetcher, currencyService: currencyService)

        let pipeline = dep.pipeline
        let tokensService = dep.tokensService

        let token = Token(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000007"), server: .main, decimals: 18, value: "2000000020224719101120", type: .erc20)

        let task1 = tokensService.addOrUpdateTokenTestsOnly(token: token)
        _ = await task1.value

        let tokenBalanceUpdateCallbackExpectation1 = self.expectation(description: "did emit initial token view model")
        var _cancelable1: AnyCancellable?
        _cancelable1 = pipeline
                .tokenViewModelPublisher(for: token)
                .sink { value in
                    if value != nil && _cancelable1 != nil {
                        _cancelable1?.cancel()
                        _cancelable1 = nil
                        tokenBalanceUpdateCallbackExpectation1.fulfill()
                    }
                }
        await fulfillment(of: [tokenBalanceUpdateCallbackExpectation1], timeout: 2)
        _cancelable1?.cancel()

        let tokenBalanceUpdateCallbackExpectation2 = self.expectation(description: "did emit token view model after change")
        var _cancelable2: AnyCancellable?
        _cancelable2 = pipeline
                .tokenViewModelPublisher(for: token)
                .sink { value in
                    if value?.balance.value == BigUInt("3000000020224719101120")! {
                        if _cancelable2 != nil {
                            _cancelable2?.cancel()
                            _cancelable2 = nil
                            tokenBalanceUpdateCallbackExpectation2.fulfill()
                        }
                    }
                }

        let task2 = tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("3000000020224719101120")!), for: token)
        _ = await task2.value
        await fulfillment(of: [tokenBalanceUpdateCallbackExpectation2], timeout: 2)

        let tokenToTicker = TokenMappedToTicker(token: token)
        let ticker = CoinTicker.make(for: tokenToTicker, currency: currencyService.currency)
        let tokenBalanceUpdateCallbackExpectation3 = self.expectation(description: "did emit for token ticker price change")
        var _cancelable3: AnyCancellable?
        _cancelable3 = pipeline
                .tokenViewModelPublisher(for: token)
                .sink { value in
                    if value?.balance.ticker?.price_usd == 666 && _cancelable3 != nil {
                        _cancelable3?.cancel()
                        _cancelable3 = nil
                        tokenBalanceUpdateCallbackExpectation3.fulfill()
                    }
                }
        await coinTickersFetcher.addOrUpdateTestsOnly(ticker: ticker.override(price_usd: 666), for: tokenToTicker).value
        await fulfillment(of: [tokenBalanceUpdateCallbackExpectation3], timeout: 2)

        let tokenBalanceUpdateCallbackExpectation4 = self.expectation(description: "did emit again for token ticker price change")
        var _cancelable4: AnyCancellable?
        _cancelable4 = pipeline
                .tokenViewModelPublisher(for: token)
                .sink { value in
                    if value?.balance.ticker?.price_usd == 1 && _cancelable4 != nil {
                        _cancelable4?.cancel()
                        _cancelable4 = nil
                        tokenBalanceUpdateCallbackExpectation4.fulfill()
                    }
                }
        await coinTickersFetcher.addOrUpdateTestsOnly(ticker: ticker.override(price_usd: 1), for: tokenToTicker).value // no changes should be, as value is stay the same
        await fulfillment(of: [tokenBalanceUpdateCallbackExpectation4], timeout: 2)
    }

    func testBalanceUpdates() async {
        //Don't share these among the test cases
        let coinTickersFetcher = CoinTickers.make()
        let currencyService: CurrencyService = .make()
        let dep = WalletDataProcessingPipeline.make(wallet: .make(), server: .main, coinTickersFetcher: coinTickersFetcher, currencyService: currencyService)

        let pipeline = dep.pipeline
        let tokensService = dep.tokensService

        let token = Token(
                contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000002"),
                server: .main,
                decimals: 18,
                value: "2000000020224719101120",
                type: .erc20)

        var balance = await pipeline.tokenViewModel(for: token)
        XCTAssertNil(balance)

        let isNotNilInitialValueExpectation = self.expectation(description: "Non nil value when subscribe for publisher")

        var _cancelable1: AnyCancellable?
        _cancelable1 = pipeline.tokenViewModelPublisher(for: token)
                .receive(on: RunLoop.main)
                .sink {
                    XCTAssertNil($0)
                    if _cancelable1 != nil {
                        _cancelable1?.cancel()
                        _cancelable1 = nil
                        isNotNilInitialValueExpectation.fulfill()
                    }
                }

        await fulfillment(of: [isNotNilInitialValueExpectation], timeout: 1)

        let task = tokensService.addOrUpdateTokenTestsOnly(token: token)
        _ = await task.value

        balance = await pipeline.tokenViewModel(for: token)
        XCTAssertNotNil(balance)

        let hasInitialValueExpectation = self.expectation(description: "Initial value when subscribe for publisher")
        var _cancelable2: AnyCancellable?
        _cancelable2 = pipeline.tokenViewModelPublisher(for: token)
                .receive(on: RunLoop.main) //NOTE: async to wait for cancelable being assigned
                .sink {
                    XCTAssertNotNil($0)
                    if _cancelable2 != nil {
                        _cancelable2?.cancel()
                        _cancelable2 = nil
                        hasInitialValueExpectation.fulfill()
                    }
                }

        await fulfillment(of: [hasInitialValueExpectation], timeout: 1)
    }

    func testBalanceUpdatesPublisherWhenServersChanged() async {
        //Don't share these among the test cases
        let coinTickersFetcher = CoinTickers.make()
        let currencyService: CurrencyService = .make()
        let dep = WalletDataProcessingPipeline.make(wallet: .make(), server: .main, coinTickersFetcher: coinTickersFetcher, currencyService: currencyService)

        let pipeline = dep.pipeline
        let tokensService = dep.tokensService
        let token = Token(
                contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000003"),
                server: .main,
                decimals: 18,
                value: "2000000020224719101120",
                type: .erc20)

        var balance = await pipeline.tokenViewModel(for: token)
        XCTAssertNil(balance)

        let task = tokensService.addOrUpdateTokenTestsOnly(token: token)
        _ = await task.value

        balance = await pipeline.tokenViewModel(for: token)
        XCTAssertNotNil(balance)

        let tokenToTicker = TokenMappedToTicker(token: token)
        let ticker = CoinTicker.make(for: tokenToTicker, currency: currencyService.currency)
        let task2 = coinTickersFetcher.addOrUpdateTestsOnly(ticker: ticker, for: tokenToTicker)
        _ = await task2.value

        let callbackCount = 10
        let tokenBalanceUpdateCallbackExpectation = self.expectation(description: "did update token balance expectation")
        tokenBalanceUpdateCallbackExpectation.expectedFulfillmentCount = callbackCount + 1
        tokenBalanceUpdateCallbackExpectation.assertForOverFulfill = false

        var _cancellable: AnyCancellable?
        _cancellable = pipeline
                .tokenViewModelPublisher(for: token)
                .sink { _ in
                    tokenBalanceUpdateCallbackExpectation.fulfill()
                }

        for each in 0 ..< callbackCount {
            if each % 2 == 0 {
                guard let testValue1 = BigUInt("10000000000000000000\(each)") else { return }
                let task = tokensService.setBalanceTestsOnly(balance: .init(value: testValue1), for: token)
                _ = await task.value
            } else {
                await coinTickersFetcher.addOrUpdateTestsOnly(ticker: ticker.override(price_usd: ticker.price_usd + Double(each)), for: tokenToTicker).value
            }
        }

        //await fulfillment(of: [tokenBalanceUpdateCallbackExpectation], timeout: TimeInterval(callbackCount + 1))
        await fulfillment(of: [tokenBalanceUpdateCallbackExpectation], timeout: 0.1)
        //Otherwise publisher might continue to emit and sink and we get unexpected values (nil token as of 20231012) because the pipeline has been destroyed
        _cancellable?.cancel()
        _cancellable = nil
    }

    func testTokenDeletion() async {
        //Don't share these among the test cases
        let coinTickersFetcher = CoinTickers.make()
        let currencyService: CurrencyService = .make()
        let dep = WalletDataProcessingPipeline.make(wallet: .make(), server: .main, coinTickersFetcher: coinTickersFetcher, currencyService: currencyService)

        let pipeline = dep.pipeline
        let tokensService = dep.tokensService
        let token = Token(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000005"), server: .main, decimals: 18, value: "0", type: .erc721)
        let task = tokensService.addOrUpdateTokenTestsOnly(token: token)
        _ = await task.value

        let tokenBalanceUpdateCallbackExpectation = self.expectation(description: "did update token balance expectation 1")

        var _cancelable: AnyCancellable?
        _cancelable = pipeline.tokenViewModelPublisher(for: token)
                .sink { value in
                    if value == nil && _cancelable != nil {
                        _cancelable?.cancel()
                        _cancelable = nil
                        tokenBalanceUpdateCallbackExpectation.fulfill()
                    }
                }
        tokensService.deleteTokenTestsOnly(token: token)
        await fulfillment(of: [tokenBalanceUpdateCallbackExpectation], timeout: 1)
    }

    @MainActor func testBalanceUpdatesPublisherWhenNonFungibleBalanceUpdated() async {
        //Don't share these among the test cases
        let coinTickersFetcher = CoinTickers.make()
        let currencyService: CurrencyService = .make()
        let dep = WalletDataProcessingPipeline.make(wallet: .make(), server: .main, coinTickersFetcher: coinTickersFetcher, currencyService: currencyService)

        let pipeline = dep.pipeline
        let tokensService = dep.tokensService

        let token = Token(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000004"), server: .main, decimals: 18, value: "0", type: .erc721)
        var tokenViewModel = await pipeline.tokenViewModel(for: token)
        XCTAssertNil(tokenViewModel)

        let task = tokensService.addOrUpdateTokenTestsOnly(token: token)
        _ = await task.value

        tokenViewModel = await pipeline.tokenViewModel(for: token)
        XCTAssertNotNil(tokenViewModel)

        let callbackCount = 10
        let tokenBalanceUpdateCallbackExpectation = self.expectation(description: "did update token balance expectation")
        tokenBalanceUpdateCallbackExpectation.expectedFulfillmentCount = callbackCount
        tokenBalanceUpdateCallbackExpectation.assertForOverFulfill = false

        var _cancellable: AnyCancellable?
        _cancellable = pipeline.tokenViewModelPublisher(for: token)
                .sink { value in
                    XCTAssertNotNil(value)
                    tokenBalanceUpdateCallbackExpectation.fulfill()
                }

        for each in 0 ..< callbackCount {
            _ = await tokensService.setNftBalanceTestsOnly(.balance(["0x0\(each)"]), for: token).value
        }

        await fulfillment(of: [tokenBalanceUpdateCallbackExpectation], timeout: 0.1)
        //Otherwise publisher might continue to emit and sink and we get unexpected values (nil token as of 20231012) because the pipeline has been destroyed
        _cancellable?.cancel()
        _cancellable = nil
    }

    func testBalanceUpdatesPublisherWhenFungibleBalanceUpdated() async {
        //Don't share these among the test cases
        let coinTickersFetcher = CoinTickers.make()
        let currencyService: CurrencyService = .make()
        let dep = WalletDataProcessingPipeline.make(wallet: .make(), server: .main, coinTickersFetcher: coinTickersFetcher, currencyService: currencyService)

        let token = Token(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000001"), server: .main, decimals: 18, value: "2000000020224719101120", type: .erc20)
        let pipeline = dep.pipeline
        let tokensService = dep.tokensService
        var balance = await pipeline.tokenViewModel(for: token)
        XCTAssertNil(balance)

        let updateTask = dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        _ = await updateTask.value
        balance = await pipeline.tokenViewModel(for: token)
        XCTAssertNotNil(balance)

        let callbackCount = 10
        let tokenBalanceUpdateCallbackExpectation = self.expectation(description: "did update token balance expectation")
        tokenBalanceUpdateCallbackExpectation.expectedFulfillmentCount = callbackCount
        tokenBalanceUpdateCallbackExpectation.assertForOverFulfill = false

        var _cancellable: AnyCancellable?
        _cancellable = pipeline.tokenViewModelPublisher(for: token)
                .sink { _ in
                    tokenBalanceUpdateCallbackExpectation.fulfill()
                }

        for each in 1 ... callbackCount {
            guard let testValue1 = BigUInt("10000000000000000000\(each)") else { return }
            let task = tokensService.setBalanceTestsOnly(balance: .init(value: testValue1), for: token)
            _ = await task.value
        }

        await fulfillment(of: [tokenBalanceUpdateCallbackExpectation], timeout: 1)
        //Otherwise publisher might continue to emit and sink and we get unexpected values (nil token as of 20231012) because the pipeline has been destroyed
        _cancellable?.cancel()
        _cancellable = nil
    }

    func testUpdateNativeCryptoBalance() async {
        //Don't share these among the test cases
        let coinTickersFetcher = CoinTickers.make()
        let currencyService: CurrencyService = .make()
        let dep = WalletDataProcessingPipeline.make(wallet: .make(), server: .main, coinTickersFetcher: coinTickersFetcher, currencyService: currencyService)

        let token = Token(contract: .make(), server: .main, value: "0", type: .nativeCryptocurrency)
        let pipeline = dep.pipeline

        let task1 = dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        _ = await task1.value

        let viewModel = await pipeline.tokenViewModel(for: token)
        XCTAssertEqual(viewModel!.balance.value, .zero)

        let testValue1 = BigUInt("10000000000000000000000")
        let task2 = dep.tokensService.setBalanceTestsOnly(balance: .init(value: testValue1), for: token)
        _ = await task2.value

        let viewModel2 = await pipeline.tokenViewModel(for: token)
        XCTAssertEqual(viewModel2!.balance.value, testValue1)

        let testValue2 = BigUInt("20000000000000000000000")
        let task3 = dep.tokensService.setBalanceTestsOnly(balance: .init(value: testValue2), for: token)
        _ = await task3.value

        let viewModel3 = await pipeline.tokenViewModel(for: token)
        XCTAssertNotNil(viewModel3)
        let viewModel4 = await pipeline.tokenViewModel(for: token)
        XCTAssertEqual(viewModel4!.balance.value, testValue2)
    }

}
