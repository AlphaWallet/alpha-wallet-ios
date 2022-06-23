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

class SendViewControllerTests: XCTestCase {
    private lazy var tokenBalanceService = FakeSingleChainTokenBalanceService(wallet: .make(), server: .main, etherToken: token)
    private let token = TokenObject(contract: AlphaWallet.Address.make(), server: .main, value: "0", type: .nativeCryptocurrency)
    private lazy var nativeCryptocurrencyTransactionType: TransactionType = {
        return .nativeCryptocurrency(token, destination: nil, amount: nil)
    }()
    private var cancelable = Set<AnyCancellable>()
    private lazy var session: WalletSession = {
        tokenBalanceService.addOrUpdateTokenTestsOnly(token: Token(tokenObject: token))
        tokenBalanceService.start()
        return .make(tokenBalanceService: tokenBalanceService)
    }()

    func testBalanceUpdates() {
        let wallet: Wallet = .make()
        let tokenBalanceService = FakeSingleChainTokenBalanceService(wallet: wallet, server: .main, etherToken: token)
        tokenBalanceService.start()

        let token = TokenObject(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000002"), server: .main, decimals: 18, value: "2000000020224719101120", type: .erc20)
        var balance = tokenBalanceService.tokenBalance(token.addressAndRPCServer)
        XCTAssertNil(balance)

        let isNotNilInitialValueExpectation = self.expectation(description: "Non nil value when subscribe for publisher")

        tokenBalanceService.tokenBalancePublisher(token.addressAndRPCServer)
            .sink { value in
                guard value == nil else { return }
                isNotNilInitialValueExpectation.fulfill()
            }.store(in: &cancelable)
        waitForExpectations(timeout: 10)

        tokenBalanceService.addOrUpdateTokenTestsOnly(token: Token(tokenObject: token))

        balance = tokenBalanceService.tokenBalance(token.addressAndRPCServer)
        XCTAssertNotNil(balance)

        let hasInitialValueExpectation = self.expectation(description: "Initial value  when subscribe for publisher")
        tokenBalanceService.tokenBalancePublisher(token.addressAndRPCServer)
            .sink { value in
                guard value != nil else { return }
                hasInitialValueExpectation.fulfill()
            }.store(in: &cancelable)

        waitForExpectations(timeout: 10)
    }

    func testBalanceUpdatesPublisherWhenServersChanged() {
        let wallet: Wallet = .make()
        let tokenBalanceService = FakeSingleChainTokenBalanceService(wallet: wallet, server: .main, etherToken: token)
        tokenBalanceService.start()

        let token = Token(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000003"), server: .main, decimals: 18, value: "2000000020224719101120", type: .erc20)
        var balance = tokenBalanceService.tokenBalance(token.addressAndRPCServer)
        XCTAssertNil(balance)

        tokenBalanceService.addOrUpdateTokenTestsOnly(token: token)

        balance = tokenBalanceService.tokenBalance(token.addressAndRPCServer)
        XCTAssertNotNil(balance)

        let tokenBalanceUpdateCallbackExpectation = self.expectation(description: "did update token balance expectation")
        var callbackCount: Int = 0
        let callbackCountExpectation: Int = 13

        tokenBalanceService.tokenBalancePublisher(token.addressAndRPCServer)
            .sink { _ in
                callbackCount += 1

                if callbackCount == callbackCountExpectation {
                    tokenBalanceUpdateCallbackExpectation.fulfill()
                }
            }.store(in: &cancelable)

        tokenBalanceService.triggerUpdateBalanceSubjectTestsOnly(wallet: wallet)

        let group = DispatchGroup()
        for each in 0 ..< 10 {
            group.enter()
            if each % 2 == 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(each)) {
                    guard let testValue1 = BigInt("10000000000000000000\(each)") else { return }
                    tokenBalanceService.setBalanceTestsOnly(balance: .init(value: testValue1), forToken: token)
                    group.leave()
                }
            } else {
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(each)) {
                    tokenBalanceService.triggerUpdateBalanceSubjectTestsOnly(wallet: wallet)
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            tokenBalanceService.deleteTokenTestsOnly(token: token)
        }

        waitForExpectations(timeout: 30)
    }

    func testTokenDeletion() {
        let wallet: Wallet = .make()
        let tokenBalanceService = FakeSingleChainTokenBalanceService(wallet: wallet, server: .main, etherToken: token)
        tokenBalanceService.start()

        let token = Token(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000005"), server: .main, decimals: 18, value: "0", type: .erc721)
        tokenBalanceService.addOrUpdateTokenTestsOnly(token: token)

        let tokenBalanceUpdateCallbackExpectation = self.expectation(description: "did update token balance expectation 1")
        var callbackCount: Int = 0
        var callbackCount2: Int = 0

        let tokenBalanceUpdateCallback2Expectation = self.expectation(description: "did update token balance expectation 2")
        let callbackCountExpectation: Int = 2
        let callbackCount2Expectation: Int = 1

        tokenBalanceService.tokenBalancePublisher(token.addressAndRPCServer)
            .sink { value in
                if callbackCount2 == 0 {
                    XCTAssertNotNil(value)
                }

                callbackCount += 1
                if callbackCount == callbackCountExpectation {
                    tokenBalanceUpdateCallbackExpectation.fulfill()
                }
            }.store(in: &cancelable)

        tokenBalanceService.deleteTokenTestsOnly(token: token)

        tokenBalanceService.tokenBalancePublisher(token.addressAndRPCServer)
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
        let wallet: Wallet = .make()
        let tokenBalanceService = FakeSingleChainTokenBalanceService(wallet: wallet, server: .main, etherToken: token)
        tokenBalanceService.start()

        let token = Token(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000004"), server: .main, decimals: 18, value: "0", type: .erc721)
        var balance = tokenBalanceService.tokenBalance(token.addressAndRPCServer)
        XCTAssertNil(balance)

        tokenBalanceService.addOrUpdateTokenTestsOnly(token: token)

        balance = tokenBalanceService.tokenBalance(token.addressAndRPCServer)
        XCTAssertNotNil(balance)

        let tokenBalanceUpdateCallbackExpectation = self.expectation(description: "did update token balance expectation")
        var callbackCount: Int = 0
        let callbackCountExpectation: Int = 11 // initial + 10

        tokenBalanceService.tokenBalancePublisher(token.addressAndRPCServer)
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
                    tokenBalanceService.setNftBalanceTestsOnly(["0x0\(each)"], forToken: token)
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(each)) {
                    tokenBalanceService.setNftBalanceTestsOnly(["0x0\(each)"], forToken: token)
                }
            }
        }

        waitForExpectations(timeout: 30)
    }

    func testBalanceUpdatesPublisherWhenFungibleBalanceUpdated() {
        let wallet: Wallet = .make()
        let tokenBalanceService = FakeSingleChainTokenBalanceService(wallet: wallet, server: .main, etherToken: token)
        tokenBalanceService.start()

        let token = Token(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000001"), server: .main, decimals: 18, value: "2000000020224719101120", type: .erc20)
        var balance = tokenBalanceService.tokenBalance(token.addressAndRPCServer)
        XCTAssertNil(balance)

        tokenBalanceService.addOrUpdateTokenTestsOnly(token: token)

        balance = tokenBalanceService.tokenBalance(token.addressAndRPCServer)
        XCTAssertNotNil(balance)

        let tokenBalanceUpdateCallbackExpectation = self.expectation(description: "did update token balance expectation")
        var callbackCount: Int = 0
        let callbackCountExpectation: Int = 11 // initial + 10 + 5

        tokenBalanceService.tokenBalancePublisher(token.addressAndRPCServer)
            .sink { _ in
                callbackCount += 1

                if callbackCount == callbackCountExpectation {
                    tokenBalanceUpdateCallbackExpectation.fulfill()
                }
            }.store(in: &cancelable)

        for each in 1 ... 10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(each)) {
                guard let testValue1 = BigInt("10000000000000000000\(each)") else { return }
                tokenBalanceService.setBalanceTestsOnly(balance: .init(value: testValue1), forToken: token)
            }
        }

        waitForExpectations(timeout: 30)
    }

    func testUpdateNativeCryptoBalance() {
        let token = TokenObject(contract: AlphaWallet.Address.make(), server: .main, value: "0", type: .nativeCryptocurrency)
        let tokenBalanceService = FakeSingleChainTokenBalanceService(wallet: .make(), server: .main, etherToken: token)
        let session: WalletSession = {
            tokenBalanceService.addOrUpdateTokenTestsOnly(token: Token(tokenObject: token))
            tokenBalanceService.start()
            return .make(tokenBalanceService: tokenBalanceService)
        }()

        XCTAssertEqual(session.tokenBalanceService.etherToken.primaryKey, token.primaryKey)
        XCTAssertNotNil(session.tokenBalanceService.ethBalanceViewModel)
        XCTAssertEqual(session.tokenBalanceService.ethBalanceViewModel!.value, .zero)

        let testValue1 = BigInt("10000000000000000000000")
        tokenBalanceService.setBalanceTestsOnly(balance: .init(value: testValue1), forToken: Token(tokenObject: token))

        XCTAssertEqual(session.tokenBalanceService.ethBalanceViewModel!.value, testValue1)

        let testValue2 = BigInt("20000000000000000000000")
        tokenBalanceService.setBalanceTestsOnly(balance: .init(value: testValue2), forToken: Token(tokenObject: token))

        XCTAssertNotNil(session.tokenBalanceService.ethBalanceViewModel)
        XCTAssertEqual(session.tokenBalanceService.ethBalanceViewModel!.value, testValue2)
    }

    func testNativeCryptocurrencyAllFundsValueSpanish() {
        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: nativeCryptocurrencyTransactionType)

        XCTAssertEqual(vc.amountTextField.value, "")

        let testValue = BigInt("10000000000000000000000")
        tokenBalanceService.setBalanceTestsOnly(balance: .init(value: testValue), forToken: Token(tokenObject: token))

        vc.allFundsSelected()
        XCTAssertEqual(vc.amountTextField.value, "10000")

        //Reset language to default
        Config.setLocale(AppLocale.system)
    }

    func testNativeCryptocurrencyAllFundsValueEnglish() {
        let vc = createSendViewControllerAndSetLocale(locale: .japanese, transactionType: nativeCryptocurrencyTransactionType)

        XCTAssertEqual(vc.amountTextField.value, "")

        let testValue = BigInt("10000000000000000000000")
        tokenBalanceService.setBalanceTestsOnly(balance: .init(value: testValue), forToken: Token(tokenObject: token))

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
        tokenBalanceService.setBalanceTestsOnly(balance: .init(value: testValue), forToken: Token(tokenObject: token))

        vc.allFundsSelected()

        XCTAssertEqual(vc.amountTextField.value, "0.00001")
        XCTAssertNotNil(vc.shortValueForAllFunds)
        XCTAssertTrue((vc.shortValueForAllFunds ?? "").nonEmpty)

        Config.setLocale(AppLocale.system)
    }

    func testERC20AllFunds() {
        let token = TokenObject(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "2000000020224719101120", type: .erc20)
        tokenBalanceService.addOrUpdateTokenTestsOnly(token: Token(tokenObject: token))
        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: .erc20Token(token, destination: .none, amount: nil))
        tokenBalanceService.setBalanceTestsOnly(balance: .init(value: BigInt("2000000020224719101120")), forToken: Token(tokenObject: token))
        XCTAssertEqual(vc.amountTextField.value, "")
        vc.allFundsSelected()

        XCTAssertEqual(vc.amountTextField.value, "2000")
        XCTAssertNotNil(vc.shortValueForAllFunds)
        XCTAssertTrue((vc.shortValueForAllFunds ?? "").nonEmpty)

        tokenBalanceService.setBalanceTestsOnly(balance: .init(value: .zero), forToken: Token(tokenObject: token))
        vc.allFundsSelected()
        XCTAssertEqual(vc.amountTextField.value, "0")

        Config.setLocale(AppLocale.system)
    }

    func testERC20AllFundsSpanish() {
        let token = TokenObject(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "0", type: .erc20)
        tokenBalanceService.addOrUpdateTokenTestsOnly(token: Token(tokenObject: token))
        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: .erc20Token(token, destination: .none, amount: nil))
        tokenBalanceService.setBalanceTestsOnly(balance: .init(value: BigInt("2020224719101120")), forToken: Token(tokenObject: token))
        XCTAssertEqual(vc.amountTextField.value, "")

        vc.allFundsSelected()

        XCTAssertEqual(vc.amountTextField.value, "0,002")
        XCTAssertNotNil(vc.shortValueForAllFunds)
        XCTAssertTrue((vc.shortValueForAllFunds ?? "").nonEmpty)

        Config.setLocale(AppLocale.system)
    }

    func testTokenBalance() {
        let token = TokenObject(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "2020224719101120", type: .erc20)
        tokenBalanceService.addOrUpdateTokenTestsOnly(token: Token(tokenObject: token))

        let tokens = tokenBalanceService.tokensDataStore.enabledTokens(for: [.main])

        XCTAssertTrue(tokens.contains(Token(tokenObject: token)))

        let viewModel = tokenBalanceService.tokenBalance(token.addressAndRPCServer)
        XCTAssertNotNil(viewModel)
        XCTAssertEqual(viewModel!.value, BigInt("2020224719101120")!)

        tokenBalanceService.setBalanceTestsOnly(balance: .init(value: BigInt("10000000000000")), forToken: Token(tokenObject: token))

        let viewModel_2 = tokenBalanceService.tokenBalance(token.addressAndRPCServer)
        XCTAssertNotNil(viewModel_2)
        XCTAssertEqual(viewModel_2!.value, BigInt("10000000000000")!)
    }

    func testERC20AllFundsEnglish() {
        let token = TokenObject(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "0", type: .erc20)
        tokenBalanceService.addOrUpdateTokenTestsOnly(token: Token(tokenObject: token))
        let vc = createSendViewControllerAndSetLocale(locale: .english, transactionType: .erc20Token(token, destination: .none, amount: nil))
        tokenBalanceService.setBalanceTestsOnly(balance: .init(value: BigInt("2020224719101120")), forToken: Token(tokenObject: token))

        XCTAssertEqual(vc.amountTextField.value, "")

        vc.allFundsSelected()

        XCTAssertEqual(vc.amountTextField.value, "0.002")
        XCTAssertNotNil(vc.shortValueForAllFunds)
        XCTAssertTrue((vc.shortValueForAllFunds ?? "").nonEmpty)

        Config.setLocale(AppLocale.system)
    }

    func testERC20English() {
        let token = TokenObject(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "0", type: .erc20)
        tokenBalanceService.addOrUpdateTokenTestsOnly(token: Token(tokenObject: token))
        let vc = createSendViewControllerAndSetLocale(locale: .english, transactionType: .erc20Token(token, destination: .none, amount: nil))
        tokenBalanceService.setBalanceTestsOnly(balance: .init(value: BigInt("2020224719101120")), forToken: Token(tokenObject: token))
        XCTAssertEqual(vc.amountTextField.value, "")

        XCTAssertNil(vc.shortValueForAllFunds)
        XCTAssertFalse((vc.shortValueForAllFunds ?? "").nonEmpty)

        Config.setLocale(AppLocale.system)

    }

    private func createSendViewControllerAndSetLocale(locale: AppLocale, transactionType: TransactionType) -> SendViewController {

        Config.setLocale(locale)

        let vc = SendViewController(session: session,
                                    tokensDataStore: tokenBalanceService.tokensDataStore,
                                    transactionType: nativeCryptocurrencyTransactionType,
                                    domainResolutionService: FakeDomainResolutionService())

        vc.configure(viewModel: .init(transactionType: transactionType, session: session, tokensDataStore: tokenBalanceService.tokensDataStore))

        return vc
    }
}
