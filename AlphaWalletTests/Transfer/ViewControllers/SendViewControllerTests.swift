// Copyright © 2021 Stormbird PTE. LTD.

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

    @MainActor func testNativeCryptocurrencyAllFundsValueSpanish() async {
        defer {
            Config.setLocale(AppLocale.system)
        }

        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: nativeCryptocurrencyTransactionType)

        XCTAssertEqual(vc.amountTextField.value, "")

        let testValue = BigUInt("10000000000000000000000")
        let task = dep.tokensService.setBalanceTestsOnly(balance: .init(value: testValue), for: token)
        _ = await task.value

        vc.allFundsSelected()
        let expectation1 = self.expectation(description: "Give async operations chance to complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(vc.amountTextField.value, "10000")
            expectation1.fulfill()
        }
        await fulfillment(of: [expectation1], timeout: 2)
    }

    @MainActor func testNativeCryptocurrencyAllFundsValueEnglish() async {
        defer {
            Config.setLocale(AppLocale.system)
        }

        let vc = createSendViewControllerAndSetLocale(locale: .japanese, transactionType: nativeCryptocurrencyTransactionType)

        XCTAssertEqual(vc.amountTextField.value, "")

        let testValue = BigUInt("10000000000000000000000")
        let task = dep.tokensService.setBalanceTestsOnly(balance: .init(value: testValue), for: token)
        _ = await task.value

        vc.allFundsSelected()
        let expectation1 = self.expectation(description: "Give async operations chance to complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(vc.amountTextField.value, "10000")
            XCTAssertTrue(vc.viewModel.amountToSend == .allFunds)
            expectation1.fulfill()
        }
        await fulfillment(of: [expectation1], timeout: 2)
    }

    @MainActor func testNativeCryptocurrencyAllFundsValueEnglish2() async {
        defer {
            Config.setLocale(AppLocale.system)
        }

        let vc = createSendViewControllerAndSetLocale(locale: .english, transactionType: nativeCryptocurrencyTransactionType)

        XCTAssertEqual(vc.amountTextField.value, "")

        let testValue = BigUInt("10000000000000")
        let task = dep.tokensService.setBalanceTestsOnly(balance: .init(value: testValue), for: token)
        _ = await task.value

        vc.allFundsSelected()

        let expectation1 = self.expectation(description: "Give async operations chance to complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(vc.amountTextField.value, "0.00001")
            XCTAssertTrue(vc.viewModel.amountToSend == .allFunds)
            expectation1.fulfill()
        }
        await fulfillment(of: [expectation1], timeout: 2)
    }

    @MainActor func testERC20IntialAllFunds() async {
        defer {
            Config.setLocale(AppLocale.system)
        }

        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "2000000020224719101120", type: .erc20)
        let task1 = dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        _ = await task1.value

        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: .erc20Token(token, destination: .none, amount: .amount(0.002)))

        let task2 = dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("2000000020224719101120")), for: token)
        _ = await task2.value
        let expectation1 = self.expectation(description: "Give async operations chance to complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(vc.amountTextField.value, "0,002")
            XCTAssertTrue(vc.viewModel.amountToSend == .amount(0.002))
            expectation1.fulfill()
        }
        await fulfillment(of: [expectation1], timeout: 1)

        vc.allFundsSelected()
        let expectation2 = self.expectation(description: "Give async operations chance to complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(vc.viewModel.amountToSend == .allFunds)
            expectation2.fulfill()
        }
        await fulfillment(of: [expectation2], timeout: 2)
    }

    @MainActor func testERC20AllFunds() async {
        defer {
            Config.setLocale(AppLocale.system)
        }

        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "2000000020224719101120", type: .erc20)
        let task1 = dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        _ = await task1.value
        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: .erc20Token(token, destination: .none, amount: .notSet))
        let task2 = dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("2000000020224719101120")), for: token)
        _ = await task2.value
        XCTAssertEqual(vc.amountTextField.value, "")

        vc.allFundsSelected()
        let expectation1 = self.expectation(description: "to test if this wait makes a difference to fire the out.amountTextFieldState.sink 1")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(vc.amountTextField.value, "2000")
            XCTAssertTrue(vc.viewModel.amountToSend == .allFunds)

            expectation1.fulfill()
        }
        await fulfillment(of: [expectation1], timeout: 2)

        let expectation2 = self.expectation(description: "to test if this wait makes a difference to fire the out.amountTextFieldState.sink")
        let task3 = dep.tokensService.setBalanceTestsOnly(balance: .init(value: .zero), for: token)
        _ = await task3.value
        vc.allFundsSelected()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(vc.amountTextField.value, "")
            XCTAssertTrue(vc.viewModel.amountToSend == .allFunds)
            expectation2.fulfill()
        }
        await fulfillment(of: [expectation2], timeout: 2)
    }

    @MainActor func testERC20AllFundsSpanish() async {
        defer {
            Config.setLocale(AppLocale.system)
        }

        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "0", type: .erc20)
        let task1 = dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        _ = await task1.value
        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: .erc20Token(token, destination: .none, amount: .notSet))
        let task2 = dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("2020224719101120")), for: token)
        _ = await task2.value
        XCTAssertEqual(vc.amountTextField.value, "")

        vc.allFundsSelected()
        let expectation1 = self.expectation(description: "Give async operations chance to complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(vc.amountTextField.value, "0,002")
            expectation1.fulfill()
        }
        await fulfillment(of: [expectation1], timeout: 2)
    }

    func testTokenBalance() async {
        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "2020224719101120", type: .erc20)
        let task1 = dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        _ = await task1.value

        let tokens = await dep.tokensService.tokens(for: [.main])

        XCTAssertTrue(tokens.contains(token))

        let viewModel = await dep.pipeline.tokenViewModel(for: token)
        XCTAssertNotNil(viewModel)
        XCTAssertEqual(viewModel?.value, BigUInt("2020224719101120")!)

        let task2 = dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("10000000000000")), for: token)
        _ = await task2.value

        let viewModel_2 = await dep.pipeline.tokenViewModel(for: token)
        XCTAssertNotNil(viewModel_2)
        XCTAssertEqual(viewModel_2?.value, BigUInt("10000000000000")!)
    }

    @MainActor func testERC20AllFundsEnglish() async {
        defer {
            Config.setLocale(AppLocale.system)
        }

        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "0", type: .erc20)
        let task1 = dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        _ = await task1.value

        let vc = createSendViewControllerAndSetLocale(locale: .english, transactionType: .erc20Token(token, destination: .none, amount: .notSet))
        let task2 = dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("2020224719101120")), for: token)
        _ = await task2.value
        XCTAssertEqual(vc.amountTextField.value, "")

        vc.allFundsSelected()
        let expectation1 = self.expectation(description: "Give async operations chance to complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(vc.amountTextField.value, "0.002")
            expectation1.fulfill()
        }
        await fulfillment(of: [expectation1], timeout: 2)
    }

    @MainActor func testERC20English() async {
        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "0", type: .erc20)
        let task1 = dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        _ = await task1.value
        let vc = createSendViewControllerAndSetLocale(locale: .english, transactionType: .erc20Token(token, destination: .none, amount: .notSet))
        let task2 = dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("2020224719101120")), for: token)
        _ = await task2.value
        XCTAssertEqual(vc.amountTextField.value, "")

        Config.setLocale(AppLocale.system)

    }

    private var testScanEip681QrCodeEnglishViewController: UIViewController?

    @MainActor func testScanEip681QrCodeEnglish() async {
        defer {
            Config.setLocale(AppLocale.system)
        }

        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "0", type: .erc20)

        let task1 = dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        _ = await task1.value
        let vc = createSendViewControllerAndSetLocale(locale: .english, transactionType: .erc20Token(token, destination: .none, amount: .amount(1.34)))

        let task2 = dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("2020224719101120")), for: token)
        _ = await task2.value
        let expectation1 = self.expectation(description: "Give async operations chance to complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(vc.amountTextField.value, "1.34")
            expectation1.fulfill()
        }
        await fulfillment(of: [expectation1], timeout: 2)

        let address = AlphaWallet.Address(string: "0xbc8dafeaca658ae0857c80d8aa6de4d487577c63")!
        let server = RPCServer.main
        contractDataFetcher.contractData[.init(address: address, server: server)] = .fungibleTokenComplete(name: "erc20", symbol: "erc20", decimals: 18, value: .zero, tokenType: .erc20)

        let qrCode = "aw.app/ethereum:0xbc8dafeaca658ae0857c80d8aa6de4d487577c63@1?value=1e19"
        vc.didScanQRCode(qrCode)

        let expectation = self.expectation(description: "did update token balance expectation")
        let destination = AlphaWallet.Address(string: "0xbc8dafeaca658ae0857c80d8aa6de4d487577c63").flatMap { AddressOrDomainName(address: $0) }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
        await fulfillment(of: [expectation], timeout: 1)

        testScanEip681QrCodeEnglishViewController = vc
    }

    @MainActor func testScanEip681QrCodeSpanish() async {
        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "0", type: .erc20)
        let task1 = dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        _ = await task1.value
        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: .erc20Token(token, destination: .none, amount: .amount(1.34)))

        let task2 = dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("2020224719101120")), for: token)
        _ = await task2.value
        let expectation1 = self.expectation(description: "Give async operations chance to complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(vc.amountTextField.value, "1,34")
            expectation1.fulfill()
        }
        await fulfillment(of: [expectation1], timeout: 2)

        let address = AlphaWallet.Address(string: "0xbc8dafeaca658ae0857c80d8aa6de4d487577c63")!
        let server = RPCServer.main
        contractDataFetcher.contractData[.init(address: address, server: server)] = .fungibleTokenComplete(name: "erc20", symbol: "erc20", decimals: 18, value: .zero, tokenType: .erc20)

        vc.didScanQRCode("aw.app/ethereum:0xbc8dafeaca658ae0857c80d8aa6de4d487577c63@1?value=1e17")

        let expectation = self.expectation(description: "did update token balance expectation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
        await fulfillment(of: [expectation], timeout: 1)

        Config.setLocale(AppLocale.system)
    }

    @MainActor func testScanEip681QrCodeSpanish2() async {
        let token = Token(contract: AlphaWallet.Address.make(), server: .main, decimals: 18, value: "0", type: .erc20)
        let task1 = dep.tokensService.addOrUpdateTokenTestsOnly(token: token)
        _ = await task1.value
        let vc = createSendViewControllerAndSetLocale(locale: .spanish, transactionType: .erc20Token(token, destination: .none, amount: .allFunds))
        let task2 = dep.tokensService.setBalanceTestsOnly(balance: .init(value: BigUInt("2020224719101120")), for: token)
        _ = await task2.value
        XCTAssertEqual(vc.amountTextField.value, "")

        let tokenAreGoingToBeResolved = Token(contract: AlphaWallet.Address(string: "0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72")!, name: "erc20", symbol: "erc20", decimals: 18, type: .erc20)
        let task3 = dep.tokensService.addOrUpdateTokenTestsOnly(token: tokenAreGoingToBeResolved)
        _ = await task3.value

        vc.didScanQRCode("aw.app/ethereum:0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72@1/transfer?address=0x8e23ee67d1332ad560396262c48ffbb01f93d052&uint256=1.004e18")

        let expectation = self.expectation(description: "did update token balance expectation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            XCTAssertEqual(vc.amountTextField.value, "1,004")
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 10)

        Config.setLocale(AppLocale.system)
    }

    private func createSendViewControllerAndSetLocale(locale: AppLocale, transactionType: TransactionType) -> SendViewController {
        Config.setLocale(locale)
        let viewModel = SendViewModel(transactionType: transactionType, session: dep.sessionsProvider.session(for: .main)!, tokensPipeline: dep.pipeline, sessionsProvider: dep.sessionsProvider, tokensService: dep.tokensService)
        return SendViewController(viewModel: viewModel, domainResolutionService: FakeDomainResolutionService(), tokenImageFetcher: FakeTokenImageFetcher())
    }
}
