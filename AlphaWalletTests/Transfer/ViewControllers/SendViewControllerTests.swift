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
    private let token = Token(contract: Constants.nullAddress, server: .main, decimals: 18, value: "0", type: .nativeCryptocurrency)
    private lazy var nativeCryptocurrencyTransactionType: TransactionType = {
        return .nativeCryptocurrency(token, destination: nil, amount: .notSet)
    }()
    private let dep = WalletDataProcessingPipeline.make(wallet: .make(), server: .main)
    let contractDataFetcher = FakeContractDataFetcher()

    func testNativeCryptocurrencyAllFundsValueSpanish() {
        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: nativeCryptocurrencyTransactionType)

        XCTAssertEqual(vc.amountTextField.value, "")

        let testValue = BigUInt("10000000000000000000000")
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: testValue), for: token)

        vc.allFundsSelected()
        XCTAssertEqual(vc.amountTextField.value, "10000")

        //Reset language to default
        Config.setLocale(AppLocale.system)
    }

    func testNativeCryptocurrencyAllFundsValueEnglish() {
        let vc = createSendViewControllerAndSetLocale(locale: .japanese, transactionType: nativeCryptocurrencyTransactionType)

        XCTAssertEqual(vc.amountTextField.value, "")

        let testValue = BigUInt("10000000000000000000000")
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: testValue), for: token)

        vc.allFundsSelected()

        XCTAssertEqual(vc.amountTextField.value, "10000")
        XCTAssertTrue(vc.viewModel.amountToSend == .allFunds)

        Config.setLocale(AppLocale.system)
    }

    func testNativeCryptocurrencyAllFundsValueEnglish2() {
        let vc = createSendViewControllerAndSetLocale(locale: .english, transactionType: nativeCryptocurrencyTransactionType)

        XCTAssertEqual(vc.amountTextField.value, "")

        let testValue = BigUInt("10000000000000")
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: testValue), for: token)
        vc.allFundsSelected()

        XCTAssertEqual(vc.amountTextField.value, "0.00001")
        XCTAssertTrue(vc.viewModel.amountToSend == .allFunds)

        Config.setLocale(AppLocale.system)
    }

    func testERC20IntialAllFunds() {
        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "2000000020224719101120", type: .erc20)
        dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: .erc20Token(token, destination: .none, amount: .amount(0.002)))
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("2000000020224719101120")), for: token)
        XCTAssertEqual(vc.amountTextField.value, "0,002")

        XCTAssertTrue(vc.viewModel.amountToSend == .amount(0.002))
        vc.allFundsSelected()
        XCTAssertTrue(vc.viewModel.amountToSend == .allFunds)

        Config.setLocale(AppLocale.system)
    }

    func testERC20AllFunds() {
        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "2000000020224719101120", type: .erc20)
        dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: .erc20Token(token, destination: .none, amount: .notSet))
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("2000000020224719101120")), for: token)
        XCTAssertEqual(vc.amountTextField.value, "")
        vc.allFundsSelected()

        XCTAssertEqual(vc.amountTextField.value, "2000")
        XCTAssertTrue(vc.viewModel.amountToSend == .allFunds)

        dep.tokensService.setBalanceTestsOnly(balance: .init(value: .zero), for: token)
        vc.allFundsSelected()

        XCTAssertEqual(vc.amountTextField.value, "")
        XCTAssertTrue(vc.viewModel.amountToSend == .allFunds)

        Config.setLocale(AppLocale.system)
    }

    func testERC20AllFundsSpanish() {
        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "0", type: .erc20)
        dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: .erc20Token(token, destination: .none, amount: .notSet))
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("2020224719101120")), for: token)
        XCTAssertEqual(vc.amountTextField.value, "")

        vc.allFundsSelected()
        XCTAssertEqual(vc.amountTextField.value, "0,002")

        Config.setLocale(AppLocale.system)
    }

    func testTokenBalance() {
        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "2020224719101120", type: .erc20)
        dep.tokensService.addOrUpdateTokenTestsOnly(token: token)

        let tokens = dep.tokensService.tokens(for: [.main])

        XCTAssertTrue(tokens.contains(token))

        let viewModel = dep.pipeline.tokenViewModel(for: token)
        XCTAssertNotNil(viewModel)
        XCTAssertEqual(viewModel?.value, BigUInt("2020224719101120")!)

        dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("10000000000000")), for: token)

        let viewModel_2 = dep.pipeline.tokenViewModel(for: token)
        XCTAssertNotNil(viewModel_2)
        XCTAssertEqual(viewModel_2?.value, BigUInt("10000000000000")!)
    }

    func testERC20AllFundsEnglish() {
        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "0", type: .erc20)
        dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        let vc = createSendViewControllerAndSetLocale(locale: .english, transactionType: .erc20Token(token, destination: .none, amount: .notSet))
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("2020224719101120")), for: token)

        XCTAssertEqual(vc.amountTextField.value, "")

        vc.allFundsSelected()
        XCTAssertEqual(vc.amountTextField.value, "0.002")

        Config.setLocale(AppLocale.system)
    }

    func testERC20English() {
        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "0", type: .erc20)
        dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        let vc = createSendViewControllerAndSetLocale(locale: .english, transactionType: .erc20Token(token, destination: .none, amount: .notSet))
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("2020224719101120")), for: token)
        XCTAssertEqual(vc.amountTextField.value, "")

        Config.setLocale(AppLocale.system)

    }

    private var testScanEip681QrCodeEnglishViewController: UIViewController?

    func testScanEip681QrCodeEnglish() {
        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "0", type: .erc20)

        dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        let vc = createSendViewControllerAndSetLocale(locale: .english, transactionType: .erc20Token(token, destination: .none, amount: .amount(1.34)))
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("2020224719101120")), for: token)
        XCTAssertEqual(vc.amountTextField.value, "1.34")

        let address = AlphaWallet.Address(string: "0xbc8dafeaca658ae0857c80d8aa6de4d487577c63")!
        let server = RPCServer.main
        contractDataFetcher.contractData[.init(address: address, server: server)] = .fungibleTokenComplete(name: "erc20", symbol: "erc20", decimals: 18, value: .zero, tokenType: .erc20)

        let qrCode = "aw.app/ethereum:0xbc8dafeaca658ae0857c80d8aa6de4d487577c63@1?value=1e19"
        vc.didScanQRCode(qrCode)

        let expectation = self.expectation(description: "did update token balance expectation")
        let destination = AlphaWallet.Address(string: "0xbc8dafeaca658ae0857c80d8aa6de4d487577c63").flatMap { AddressOrDomainName(address: $0) }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            XCTAssertEqual(vc.viewModel.latestQrCode, qrCode)

            switch vc.viewModel.scanQrCodeLatest {
            case .success(let transactionType):
                XCTAssertEqual(transactionType.amount, .amount(10))
                XCTAssertEqual(transactionType.recipient, destination)
            case .failure(let e):
                XCTFail(e.description)
            case .none:
                XCTFail()
            }
            XCTAssertEqual(vc.amountTextField.value, "10")

            expectation.fulfill()
        }
        waitForExpectations(timeout: 10)

        testScanEip681QrCodeEnglishViewController = vc

        Config.setLocale(AppLocale.system)
    }

    func testScanEip681QrCodeSpanish() {
        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "0", type: .erc20)
        dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: .erc20Token(token, destination: .none, amount: .amount(1.34)))
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("2020224719101120")), for: token)
        XCTAssertEqual(vc.amountTextField.value, "1,34")

        let address = AlphaWallet.Address(string: "0xbc8dafeaca658ae0857c80d8aa6de4d487577c63")!
        let server = RPCServer.main
        contractDataFetcher.contractData[.init(address: address, server: server)] = .fungibleTokenComplete(name: "erc20", symbol: "erc20", decimals: 18, value: .zero, tokenType: .erc20)

        vc.didScanQRCode("aw.app/ethereum:0xbc8dafeaca658ae0857c80d8aa6de4d487577c63@1?value=1e17")

        let expectation = self.expectation(description: "did update token balance expectation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            switch vc.viewModel.scanQrCodeLatest {
            case .success(let transactionType):
                XCTAssertEqual(transactionType.amount, .amount(0.1))
            case .failure(let e):
                XCTFail(e.description)
            case .none:
                XCTFail()
            }

            XCTAssertEqual(vc.amountTextField.value, "0,1")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 10)

        Config.setLocale(AppLocale.system)
    }

    func testScanEip681QrCodeSpanish2() {
        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "0", type: .erc20)
        dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: .erc20Token(token, destination: .none, amount: .allFunds))
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("2020224719101120")), for: token)
        XCTAssertEqual(vc.amountTextField.value, "")

        let tokenAreGoingToBeResolved = Token(contract: AlphaWallet.Address(string: "0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72")!, name: "erc20", symbol: "erc20", decimals: 18, type: .erc20)
        dep.tokensService.addOrUpdateTokenTestsOnly(token: tokenAreGoingToBeResolved)

        vc.didScanQRCode("aw.app/ethereum:0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72@1/transfer?address=0x8e23ee67d1332ad560396262c48ffbb01f93d052&uint256=1.004e18")

        let expectation = self.expectation(description: "did update token balance expectation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            XCTAssertEqual(vc.amountTextField.value, "1,004")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 10)

        Config.setLocale(AppLocale.system)
    }

    private func createSendViewControllerAndSetLocale(locale: AppLocale, transactionType: TransactionType) -> SendViewController {
        Config.setLocale(locale)
        let viewModel = SendViewModel(transactionType: transactionType, session: dep.sessionsProvider.session(for: .main)!, tokensPipeline: dep.pipeline, sessionsProvider: dep.sessionsProvider, tokensService: dep.tokensService)
        return SendViewController(viewModel: viewModel, domainResolutionService: FakeDomainResolutionService(), tokenImageFetcher: FakeTokenImageFetcher())
    }
}

class TokenBalanceTests: XCTestCase {
    private var cancelable = Set<AnyCancellable>()
    private let coinTickersFetcher = CoinTickers.make()
    private let currencyService: CurrencyService = .make()

    lazy var dep = WalletDataProcessingPipeline.make(
        wallet: .make(),
        server: .main,
        coinTickersFetcher: coinTickersFetcher,
        currencyService: currencyService)

    func testTokenViewModelChanges() {
        let pipeline = dep.pipeline
        let tokensService = dep.tokensService

        let token = Token(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000007"), server: .main, decimals: 18, value: "2000000020224719101120", type: .erc20)

        tokensService.addOrUpdateTokenTestsOnly(token: token)

        let tokenBalanceUpdateCallbackExpectation = self.expectation(description: "did update token balance expectation")
        var callbackCount: Int = 0
        let callbackCountExpectation: Int = 4

        pipeline
            .tokenViewModelPublisher(for: token)
            .sink { _ in
                callbackCount += 1

                if callbackCount == callbackCountExpectation {
                    tokenBalanceUpdateCallbackExpectation.fulfill()
                }
            }.store(in: &cancelable)

        tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("3000000020224719101120")!), for: token)

        let tokenToTicker = TokenMappedToTicker(token: token)
        let ticker = CoinTicker.make(for: tokenToTicker, currency: currencyService.currency)

        coinTickersFetcher.addOrUpdateTestsOnly(ticker: ticker, for: tokenToTicker)
        coinTickersFetcher.addOrUpdateTestsOnly(ticker: ticker.override(price_usd: 0), for: tokenToTicker) // no changes should be, as value is stay the same
        coinTickersFetcher.addOrUpdateTestsOnly(ticker: ticker.override(price_usd: 666), for: tokenToTicker)

        tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("4000000020224719101120")!), for: token)

        waitForExpectations(timeout: 50)
    }

    func testBalanceUpdates() {
        let pipeline = dep.pipeline
        let tokensService = dep.tokensService

        let token = Token(
            contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000002"),
            server: .main,
            decimals: 18,
            value: "2000000020224719101120",
            type: .erc20)

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
        let token = Token(
            contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000003"),
            server: .main,
            decimals: 18,
            value: "2000000020224719101120",
            type: .erc20)

        var balance = pipeline.tokenViewModel(for: token)
        XCTAssertNil(balance)

        tokensService.addOrUpdateTokenTestsOnly(token: token)

        balance = pipeline.tokenViewModel(for: token)
        XCTAssertNotNil(balance)

        let tokenBalanceUpdateCallbackExpectation = self.expectation(description: "did update token balance expectation")
        var callbackCount: Int = 0
        let callbackCountExpectation: Int = 13

        pipeline
            .tokenViewModelPublisher(for: token)
            .sink { _ in
                callbackCount += 1
                if callbackCount == callbackCountExpectation {
                    tokenBalanceUpdateCallbackExpectation.fulfill()
                }
            }.store(in: &cancelable)

        let tokenToTicker = TokenMappedToTicker(token: token)
        let ticker = CoinTicker.make(for: tokenToTicker, currency: currencyService.currency)
        coinTickersFetcher.addOrUpdateTestsOnly(ticker: ticker, for: tokenToTicker)

        let group = DispatchGroup()
        for each in 0 ..< 10 {
            group.enter()
            if each % 2 == 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(each)) {
                    guard let testValue1 = BigUInt("10000000000000000000\(each)") else { return }
                    tokensService.setBalanceTestsOnly(balance: .init(value: testValue1), for: token)
                    group.leave()
                }
            } else {
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(each)) {
                    self.coinTickersFetcher.addOrUpdateTestsOnly(ticker: ticker.override(price_usd: ticker.price_usd + Double(each)), for: tokenToTicker)
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            tokensService.deleteTokenTestsOnly(token: token)
        }

        waitForExpectations(timeout: 50)
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
                guard let testValue1 = BigUInt("10000000000000000000\(each)") else { return }
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

        let testValue1 = BigUInt("10000000000000000000000")
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: testValue1), for: token)

        XCTAssertEqual(pipeline.tokenViewModel(for: token)!.balance.value, testValue1)

        let testValue2 = BigUInt("20000000000000000000000")
        dep.tokensService.setBalanceTestsOnly(balance: .init(value: testValue2), for: token)

        XCTAssertNotNil(pipeline.tokenViewModel(for: token))
        XCTAssertEqual(pipeline.tokenViewModel(for: token)!.balance.value, testValue2)
    }

}
