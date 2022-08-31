//
//  SendViewControllerTests.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 05.03.2021.
//

import UIKit
@testable import AlphaWallet
import XCTest
import BigInt
import Combine
import AlphaWalletFoundation

class SendViewControllerTests: XCTestCase {
    private let token = Token(contract: Constants.nullAddress, server: .main, value: "0", type: .nativeCryptocurrency)
    private lazy var nativeCryptocurrencyTransactionType: TransactionType = {
        return .nativeCryptocurrency(token, destination: nil, amount: nil)
    }()
    private let dep = WalletDataProcessingPipeline.make(wallet: .make(), server: .main)

    func testNativeCryptocurrencyAllFundsValueSpanish() {
        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: nativeCryptocurrencyTransactionType)

        XCTAssertEqual(vc.amountTextField.value, "")

        let testValue = BigInt("10000000000000000000000")
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: testValue), for: token)

        vc.allFundsSelected()
        XCTAssertEqual(vc.amountTextField.value, "10000")

        //Reset language to default
        Config.setLocale(AppLocale.system)
    }

    func testNativeCryptocurrencyAllFundsValueEnglish() {
        let vc = createSendViewControllerAndSetLocale(locale: .japanese, transactionType: nativeCryptocurrencyTransactionType)

        XCTAssertEqual(vc.amountTextField.value, "")

        let testValue = BigInt("10000000000000000000000")
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: testValue), for: token)

        vc.allFundsSelected()

        XCTAssertEqual(vc.amountTextField.value, "10000")
        XCTAssertNotNil(vc.shortValueForAllFunds)
        XCTAssertTrue((vc.shortValueForAllFunds ?? "").nonEmpty)

        Config.setLocale(AppLocale.system)
    }

    func testNativeCryptocurrencyAllFundsValueEnglish2() {
        let vc = createSendViewControllerAndSetLocale(locale: .english, transactionType: nativeCryptocurrencyTransactionType)

        XCTAssertEqual(vc.amountTextField.value, "")

        let testValue = BigInt("10000000000000")
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: testValue), for: token)
        vc.allFundsSelected()

        XCTAssertEqual(vc.amountTextField.value, "0.00001")
        XCTAssertNotNil(vc.shortValueForAllFunds)
        XCTAssertTrue((vc.shortValueForAllFunds ?? "").nonEmpty)

        Config.setLocale(AppLocale.system)
    }

    func testERC20AllFunds() {
        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "2000000020224719101120", type: .erc20)
        dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: .erc20Token(token, destination: .none, amount: nil))
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigInt("2000000020224719101120")), for: token)
        XCTAssertEqual(vc.amountTextField.value, "")
        vc.allFundsSelected()

        XCTAssertEqual(vc.amountTextField.value, "2000")
        XCTAssertNotNil(vc.shortValueForAllFunds)
        XCTAssertTrue((vc.shortValueForAllFunds ?? "").nonEmpty)

        dep.tokensService.setBalanceTestsOnly(balance: .init(value: .zero), for: token)
        vc.allFundsSelected()
        XCTAssertEqual(vc.amountTextField.value, "0")

        Config.setLocale(AppLocale.system)
    }

    func testERC20AllFundsSpanish() {
        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "0", type: .erc20)
        dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: .erc20Token(token, destination: .none, amount: nil))
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigInt("2020224719101120")), for: token)
        XCTAssertEqual(vc.amountTextField.value, "")

        vc.allFundsSelected()
        XCTAssertEqual(vc.amountTextField.value, "0,002")
        XCTAssertNotNil(vc.shortValueForAllFunds)
        XCTAssertTrue((vc.shortValueForAllFunds ?? "").nonEmpty)

        Config.setLocale(AppLocale.system)
    }

    func testTokenBalance() {
        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "2020224719101120", type: .erc20)
        dep.tokensService.addOrUpdateTokenTestsOnly(token: token)

        let tokens = dep.pipeline.tokens(for: [.main])

        XCTAssertTrue(tokens.contains(token))

        let viewModel = dep.pipeline.tokenViewModel(for: token)
        XCTAssertNotNil(viewModel)
        XCTAssertEqual(viewModel?.value, BigInt("2020224719101120")!)

        dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigInt("10000000000000")), for: token)

        let viewModel_2 = dep.pipeline.tokenViewModel(for: token)
        XCTAssertNotNil(viewModel_2)
        XCTAssertEqual(viewModel_2?.value, BigInt("10000000000000")!)
    }

    func testERC20AllFundsEnglish() {
        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "0", type: .erc20)
        dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        let vc = createSendViewControllerAndSetLocale(locale: .english, transactionType: .erc20Token(token, destination: .none, amount: nil))
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigInt("2020224719101120")), for: token)

        XCTAssertEqual(vc.amountTextField.value, "")

        vc.allFundsSelected()
        XCTAssertEqual(vc.amountTextField.value, "0.002")
        XCTAssertNotNil(vc.shortValueForAllFunds)
        XCTAssertTrue((vc.shortValueForAllFunds ?? "").nonEmpty)

        Config.setLocale(AppLocale.system)
    }

    func testERC20English() {
        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "0", type: .erc20)
        dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        let vc = createSendViewControllerAndSetLocale(locale: .english, transactionType: .erc20Token(token, destination: .none, amount: nil))
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigInt("2020224719101120")), for: token)
        XCTAssertEqual(vc.amountTextField.value, "")

        XCTAssertNil(vc.shortValueForAllFunds)
        XCTAssertFalse((vc.shortValueForAllFunds ?? "").nonEmpty)

        Config.setLocale(AppLocale.system)

    }

    private func createSendViewControllerAndSetLocale(locale: AppLocale, transactionType: TransactionType) -> SendViewController {

        Config.setLocale(locale)

        let vc = SendViewController(session: dep.sessionsProvider.session(for: .main)!,
                                    service: dep.pipeline,
                                    transactionType: nativeCryptocurrencyTransactionType,
                                    domainResolutionService: FakeDomainResolutionService())

        vc.configure(viewModel: .init(transactionType: transactionType, session: dep.sessionsProvider.session(for: .main)!, service: dep.pipeline))

        return vc
    }
}

class TokenBalanceTests: XCTestCase {
    private var cancelable = Set<AnyCancellable>()
    let dep = WalletDataProcessingPipeline.make(wallet: .make(), server: .main)

    func testTokenViewModelChanges() {
        let pipeline = dep.pipeline
        let tokensService = dep.tokensService

        let token = Token(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000007"), server: .main, decimals: 18, value: "2000000020224719101120", type: .erc20)

        tokensService.addOrUpdateTokenTestsOnly(token: token)

        let tokenBalanceUpdateCallbackExpectation = self.expectation(description: "did update token balance expectation")
        var callbackCount: Int = 0
        let callbackCountExpectation: Int = 4

        pipeline.tokenViewModelPublisher(for: token)
            .sink { _ in
                callbackCount += 1

                if callbackCount == callbackCountExpectation {
                    tokenBalanceUpdateCallbackExpectation.fulfill()
                }
            }.store(in: &cancelable)
        
        tokensService.setBalanceTestsOnly(balance: .init(value: BigInt("3000000020224719101120")!), for: token)

        let tokenToTicker = TokenMappedToTicker(token: token)
        let ticker = CoinTicker.make(for: tokenToTicker)

        pipeline.addOrUpdateTestsOnly(ticker: ticker, for: tokenToTicker)
        pipeline.addOrUpdateTestsOnly(ticker: ticker.override(price_usd: 0), for: tokenToTicker) // no changes should be, as value is stay the same
        pipeline.addOrUpdateTestsOnly(ticker: ticker.override(price_usd: 666), for: tokenToTicker)

        tokensService.setBalanceTestsOnly(balance: .init(value: BigInt("4000000020224719101120")!), for: token)
        
        waitForExpectations(timeout: 10)
    }

    func testBalanceUpdates() {
        let pipeline = dep.pipeline
        let tokensService = dep.tokensService

        let token = Token(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000002"), server: .main, decimals: 18, value: "2000000020224719101120", type: .erc20)
        var balance = pipeline.tokenViewModel(for: token)
        XCTAssertNil(balance)

        let isNotNilInitialValueExpectation = self.expectation(description: "Non nil value when subscribe for publisher")

        var _cancelable1: AnyCancellable?
        _cancelable1 = pipeline.tokenViewModelPublisher(for: token)
            .receive(on: RunLoop.main)
            .sink { _ in
                _cancelable1?.cancel()

                isNotNilInitialValueExpectation.fulfill()
            }

        waitForExpectations(timeout: 10)

        tokensService.addOrUpdateTokenTestsOnly(token: token)

        balance = pipeline.tokenViewModel(for: token)
        XCTAssertNotNil(balance)

        let hasInitialValueExpectation = self.expectation(description: "Initial value  when subscribe for publisher")
        var _cancelable2: AnyCancellable?
        _cancelable2 = pipeline.tokenViewModelPublisher(for: token)
            .receive(on: RunLoop.main) //NOTE: async to wait for cancelable being assigned
            .sink { _ in
                _cancelable2?.cancel()

                hasInitialValueExpectation.fulfill()
            }

        waitForExpectations(timeout: 10)
    }

    func testBalanceUpdatesPublisherWhenServersChanged() {
        let pipeline = dep.pipeline
        let tokensService = dep.tokensService
        let token = Token(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000003"), server: .main, decimals: 18, value: "2000000020224719101120", type: .erc20)
        var balance = pipeline.tokenViewModel(for: token)
        XCTAssertNil(balance)

        tokensService.addOrUpdateTokenTestsOnly(token: token)

        balance = pipeline.tokenViewModel(for: token)
        XCTAssertNotNil(balance)

        let tokenBalanceUpdateCallbackExpectation = self.expectation(description: "did update token balance expectation")
        var callbackCount: Int = 0
        let callbackCountExpectation: Int = 13

        pipeline.tokenViewModelPublisher(for: token)
            .sink { _ in
                callbackCount += 1
                if callbackCount == callbackCountExpectation {
                    tokenBalanceUpdateCallbackExpectation.fulfill()
                }
            }.store(in: &cancelable)

        let tokenToTicker = TokenMappedToTicker(token: token)
        let ticker = CoinTicker.make(for: tokenToTicker)
        pipeline.addOrUpdateTestsOnly(ticker: ticker, for: tokenToTicker)

        let group = DispatchGroup()
        for each in 0 ..< 10 {
            group.enter()
            if each % 2 == 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(each)) {
                    guard let testValue1 = BigInt("10000000000000000000\(each)") else { return }
                    tokensService.setBalanceTestsOnly(balance: .init(value: testValue1), for: token)
                    group.leave()
                }
            } else {
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(each)) {
                    pipeline.addOrUpdateTestsOnly(ticker: ticker.override(price_usd: ticker.price_usd + Double(each)), for: tokenToTicker)
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            tokensService.deleteTokenTestsOnly(token: token)
        }

        waitForExpectations(timeout: 30)
    }

    func testTokenDeletion() {
        let pipeline = dep.pipeline
        let tokensService = dep.tokensService
        let token = Token(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000005"), server: .main, decimals: 18, value: "0", type: .erc721)
        tokensService.addOrUpdateTokenTestsOnly(token: token)

        let tokenBalanceUpdateCallbackExpectation = self.expectation(description: "did update token balance expectation 1")
        var callbackCount: Int = 0
        var callbackCount2: Int = 0

        let tokenBalanceUpdateCallback2Expectation = self.expectation(description: "did update token balance expectation 2")
        let callbackCountExpectation: Int = 2
        let callbackCount2Expectation: Int = 1

        pipeline.tokenViewModelPublisher(for: token)
            .sink { value in
                if callbackCount == 0 {
                    XCTAssertNotNil(value)
                }

                callbackCount += 1
                if callbackCount == callbackCountExpectation {
                    tokenBalanceUpdateCallbackExpectation.fulfill()
                }
            }.store(in: &cancelable)

        tokensService.deleteTokenTestsOnly(token: token)

        pipeline.tokenViewModelPublisher(for: token)
            .sink { value in
                if callbackCount2 == 0 {
                    XCTAssertNil(value)
                }

                callbackCount2 += 1

                if callbackCount2 == callbackCount2Expectation {
                    tokenBalanceUpdateCallback2Expectation.fulfill()
                }
            }.store(in: &cancelable)

        waitForExpectations(timeout: 30)
    }

    func testBalanceUpdatesPublisherWhenNonFungibleBalanceUpdated() {
        let pipeline = dep.pipeline
        let tokensService = dep.tokensService

        let token = Token(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000004"), server: .main, decimals: 18, value: "0", type: .erc721)
        var balance = pipeline.tokenViewModel(for: token)
        XCTAssertNil(balance)

        tokensService.addOrUpdateTokenTestsOnly(token: token)

        balance = pipeline.tokenViewModel(for: token)
        XCTAssertNotNil(balance)

        let tokenBalanceUpdateCallbackExpectation = self.expectation(description: "did update token balance expectation")
        var callbackCount: Int = 0
        let callbackCountExpectation: Int = 11 // initial + 10

        pipeline.tokenViewModelPublisher(for: token)
            .sink { value in

                if callbackCount == 0 {
                    XCTAssertNotNil(value)
                }

                callbackCount += 1
                if callbackCount == callbackCountExpectation {
                    tokenBalanceUpdateCallbackExpectation.fulfill()
                }
            }.store(in: &cancelable)

        for each in 1 ... 10 {
            if each % 2 == 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(each)) {
                    tokensService.setNftBalanceTestsOnly(.balance(["0x0\(each)"]), for: token)
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(each)) {
                    tokensService.setNftBalanceTestsOnly(.balance(["0x0\(each)"]), for: token)
                }
            }
        }

        waitForExpectations(timeout: 30)
    }

    func testBalanceUpdatesPublisherWhenFungibleBalanceUpdated() {
        var callbackCount: Int = 0

        let token = Token(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000001"), server: .main, decimals: 18, value: "2000000020224719101120", type: .erc20)
        let pipeline = dep.pipeline
        let tokensService = dep.tokensService
        var balance = pipeline.tokenViewModel(for: token)
        XCTAssertNil(balance)

        dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        balance = pipeline.tokenViewModel(for: token)
        XCTAssertNotNil(balance)

        let tokenBalanceUpdateCallbackExpectation = self.expectation(description: "did update token balance expectation")
        let callbackCountExpectation: Int = 11 // initial + 10 + 5

        pipeline.tokenViewModelPublisher(for: token)
            .sink { _ in
                callbackCount += 1
                if callbackCount == callbackCountExpectation {
                    tokenBalanceUpdateCallbackExpectation.fulfill()
                }
            }.store(in: &cancelable)

        for each in 1 ... 10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(each)) {
                guard let testValue1 = BigInt("10000000000000000000\(each)") else { return }
                tokensService.setBalanceTestsOnly(balance: .init(value: testValue1), for: token)
            }
        }

        waitForExpectations(timeout: 30)
    }

    func testUpdateNativeCryptoBalance() {
        let token = Token(contract: .make(), server: .main, value: "0", type: .nativeCryptocurrency)
        let pipeline = dep.pipeline

        dep.tokensService.addOrUpdateTokenTestsOnly(token: token)

        XCTAssertEqual(pipeline.tokenViewModel(for: token)!.balance.value, .zero)

        let testValue1 = BigInt("10000000000000000000000")
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: testValue1), for: token)

        XCTAssertEqual(pipeline.tokenViewModel(for: token)!.balance.value, testValue1)

        let testValue2 = BigInt("20000000000000000000000")
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: testValue2), for: token)

        XCTAssertNotNil(pipeline.tokenViewModel(for: token))
        XCTAssertEqual(pipeline.tokenViewModel(for: token)!.balance.value, testValue2)
    }

}
