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

class SendViewControllerTests: XCTestCase {
    private let tokensDataStore = FakeTokensDataStore()

    private let balanceCoordinator = FakeBalanceCoordinator()
    private let nativeCryptocurrencyTransactionType: TransactionType = {
        let token = TokenObject(contract: AlphaWallet.Address.make(), server: .main, value: "0", type: .nativeCryptocurrency)
        return .nativeCryptocurrency(token, destination: nil, amount: nil)
    }()

    private lazy var session: WalletSession = .make(balanceCoordinator: balanceCoordinator)

    func testNativeCryptocurrencyAllFundsValueSpanish() {
        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: nativeCryptocurrencyTransactionType)

        XCTAssertEqual(vc.amountTextField.value, "")

        let testValue = BigInt("10000000000000000000000")
        balanceCoordinator.balance = .some(.init(value: testValue))

        vc.allFundsSelected()
        XCTAssertEqual(vc.amountTextField.value, "10000")

        //Reset language to default
        Config.setLocale(AppLocale.system)
    }

    func testNativeCryptocurrencyAllFundsValueEnglish() {
        let vc = createSendViewControllerAndSetLocale(locale: .japanese, transactionType: nativeCryptocurrencyTransactionType)

        XCTAssertEqual(vc.amountTextField.value, "")

        let testValue = BigInt("10000000000000000000000")
        balanceCoordinator.balance = .some(.init(value: testValue))

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
        balanceCoordinator.balance = .some(.init(value: testValue))

        vc.allFundsSelected()

        XCTAssertEqual(vc.amountTextField.value, "0.00001")
        XCTAssertNotNil(vc.shortValueForAllFunds)
        XCTAssertTrue((vc.shortValueForAllFunds ?? "").nonEmpty)

        Config.setLocale(AppLocale.system)
    }

    func testERC20AllFunds() {
        let token = TokenObject(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "2000000020224719101120", type: .erc20)

        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: .erc20Token(token, destination: .none, amount: nil))

        XCTAssertEqual(vc.amountTextField.value, "")

        vc.allFundsSelected()

        XCTAssertEqual(vc.amountTextField.value, "2000")
        XCTAssertNotNil(vc.shortValueForAllFunds)
        XCTAssertTrue((vc.shortValueForAllFunds ?? "").nonEmpty)

        Config.setLocale(AppLocale.system)
    }

    func testERC20AllFundsSpanish() {
        let token = TokenObject(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "2020224719101120", type: .erc20)

        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: .erc20Token(token, destination: .none, amount: nil))

        XCTAssertEqual(vc.amountTextField.value, "")

        vc.allFundsSelected()
        
        XCTAssertEqual(vc.amountTextField.value, "0,002")
        XCTAssertNotNil(vc.shortValueForAllFunds)
        XCTAssertTrue((vc.shortValueForAllFunds ?? "").nonEmpty)

        Config.setLocale(AppLocale.system)
    }

    func testERC20AllFundsEnglish() {
        let token = TokenObject(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "2020224719101120", type: .erc20)
        let vc = createSendViewControllerAndSetLocale(locale: .english, transactionType: .erc20Token(token, destination: .none, amount: nil))

        XCTAssertEqual(vc.amountTextField.value, "")

        vc.allFundsSelected()

        XCTAssertEqual(vc.amountTextField.value, "0.002")
        XCTAssertNotNil(vc.shortValueForAllFunds)
        XCTAssertTrue((vc.shortValueForAllFunds ?? "").nonEmpty)

        Config.setLocale(AppLocale.system)
    }

    func testERC20English() {
        let token = TokenObject(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "2020224719101120", type: .erc20)
        let vc = createSendViewControllerAndSetLocale(locale: .english, transactionType: .erc20Token(token, destination: .none, amount: nil))

        XCTAssertEqual(vc.amountTextField.value, "")

        XCTAssertNil(vc.shortValueForAllFunds)
        XCTAssertFalse((vc.shortValueForAllFunds ?? "").nonEmpty)

        Config.setLocale(AppLocale.system)

    }

    private func createSendViewControllerAndSetLocale(locale: AppLocale, transactionType: TransactionType) -> SendViewController {
        Config.setLocale(locale)

        let vc = SendViewController(session: session,
                                    tokensDataStore: tokensDataStore,
                                    transactionType: nativeCryptocurrencyTransactionType,
                                    cryptoPrice: Subscribable<Double>.init(nil))

        vc.configure(viewModel: .init(transactionType: transactionType, session: session, tokensDataStore: tokensDataStore))

        return vc
    }
}
