//
//  TransactionTypeFromQrCodeTests.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 08.12.2022.
//

import XCTest
@testable import AlphaWallet
import BigInt
import AlphaWalletFoundation
import AlphaWalletWeb3
import Combine

class ImportTokenTests: XCTestCase {
    private var cancelable = Set<AnyCancellable>()

    func testImportUnknownErc20Token() async throws {
        let tokensDataStore = FakeTokensDataStore()
        let server = RPCServer.main
        let contractDataFetcher = FakeContractDataFetcher(server: server)

        let importToken = ImportToken.make(tokensDataStore: tokensDataStore, contractDataFetcher: contractDataFetcher, server: server)
        let address = AlphaWallet.Address(string: "0xbc8dafeaca658ae0857c80d8aa6de4d487577c63")!

        contractDataFetcher.contractData[.init(address: address, server: server)] = .fungibleTokenComplete(name: "erc20", symbol: "erc20", decimals: 6, value: .zero, tokenType: .erc20)

        let token = await tokensDataStore.token(for: address, server: server)
        XCTAssertNil(token, "Initially token is nil")

        let expectation = self.expectation(description: "did resolve erc20 token")
        let expectationDidCheckAdd = self.expectation(description: "did check adding token token")
        importToken.importToken(for: address)
            .sink(receiveCompletion: { _ in
                expectation.fulfill()
            }, receiveValue: { token in
                XCTAssertEqual(token.type, .erc20)
                XCTAssertEqual(token.symbol, "erc20")
                XCTAssertEqual(token.decimals, 6)
                Task { @MainActor in
                    let addedToken = await tokensDataStore.token(for: address, server: server)
                    XCTAssertEqual(token, addedToken, "Token has added to storage")
                    expectationDidCheckAdd.fulfill()
                }
            }).store(in: &cancelable)

        await fulfillment(of: [expectation, expectationDidCheckAdd], timeout: 3)
    }

    func testImportNotDetectedErc20Token() throws {
        let tokensDataStore = FakeTokensDataStore()
        let server = RPCServer.main
        let contractDataFetcher = FakeContractDataFetcher(server: server)

        let importToken = ImportToken.make(tokensDataStore: tokensDataStore, contractDataFetcher: contractDataFetcher, server: server)

        let address = AlphaWallet.Address(string: "0xbc8dafeaca658ae0857c80d8aa6de4d487577c63")!

        let expectation = self.expectation(description: "did resolve erc20 token")
        expectation.isInverted = true

        importToken.importToken(for: address)
            .sink(receiveCompletion: { result in
                guard case .failure = result else { return }
                expectation.fulfill()
            }, receiveValue: { _ in

            }).store(in: &cancelable)

        waitForExpectations(timeout: 3)
    }

    func testImportAlreadyAddedErc20Token() async throws {
        let tokensDataStore = FakeTokensDataStore()
        let server = RPCServer.main
        let contractDataFetcher = FakeContractDataFetcher(server: server)

        let importToken = ImportToken.make(tokensDataStore: tokensDataStore, wallet: .make(), contractDataFetcher: contractDataFetcher, server: server)

        let address = AlphaWallet.Address(string: "0xbc8dafeaca658ae0857c80d8aa6de4d487577c63")!

        let token = Token(contract: address, server: server, value: .zero, type: .erc20)
        await tokensDataStore.addOrUpdate(with: [.init(token)])

        let expectation = self.expectation(description: "did resolve erc20 token")
        contractDataFetcher.contractData[.init(address: address, server: server)] = .fungibleTokenComplete(name: "erc20", symbol: "erc20", decimals: 6, value: BigUInt("1"), tokenType: .erc20)

        importToken.importToken(for: address)
            .sink(receiveCompletion: { _ in
                expectation.fulfill()
            }, receiveValue: { token in
                XCTAssertEqual(token.value, .zero)
            }).store(in: &cancelable)

        await fulfillment(of: [expectation], timeout: 3)
    }
}

class TransactionTypeFromQrCodeTests: XCTestCase {
    private let contractDataFetcher = FakeContractDataFetcher()

    /// Represents current transactio type
    private let transactionTypeSupportable = FakeTransactionTypeSupportable()
    private let tokensDataStore = FakeTokensDataStore()
    private lazy var fakeFakeImportToken = ImportToken.make(tokensDataStore: tokensDataStore, contractDataFetcher: contractDataFetcher)
    private var cancelable = Set<AnyCancellable>()
    private lazy var provider: TransactionTypeFromQrCode = {
        let sessions = FakeSessionsProvider(servers: [.main])
        sessions.importToken[.main] = fakeFakeImportToken
        sessions.start()

        let provider = TransactionTypeFromQrCode(sessionsProvider: sessions, session: sessions.session(for: .main)!)
        provider.transactionTypeProvider = transactionTypeSupportable

        return provider
    }()

    func testScanSmallEthTransfer() async throws {
        let expectation = self.expectation(description: "did resolve erc20 transaction type")
        let qrCode = "aw.app/ethereum:0xbc8dafeaca658ae0857c80d8aa6de4d487577c63@1?value=1e12"

        let etherToken = Token(contract: Constants.nativeCryptoAddressInDatabase, server: .main, name: "Ether", symbol: "eth", decimals: 18, type: .nativeCryptocurrency)
        //NOTE: make sure we have a eth token, base impl resolves it automatically, for test does it manually
        await tokensDataStore.addOrUpdate(with: [
            .init(etherToken)
        ])

        provider.buildTransactionType(qrCode: qrCode)
            .sink { result in
                guard case .success(let transactionType) = result else {
                    XCTFail("failure as resolved: \(result)")
                    expectation.fulfill()
                    return
                }
                guard case .nativeCryptocurrency(let token, let destination, let amount) = transactionType else {
                    XCTFail("failure as resolved: \(transactionType)")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(token, etherToken)
                XCTAssertNotNil(destination)
                XCTAssertNotNil(amount)
                XCTAssertEqual(transactionType.amount, .amount(1e-06))
                XCTAssertEqual(transactionType.recipient?.contract, AlphaWallet.Address(string: "0xbc8dafeaca658ae0857c80d8aa6de4d487577c63")!)

                expectation.fulfill()
            }.store(in: &cancelable)

        await fulfillment(of: [expectation], timeout: 3)
    }

    func testScanSmallErc20Transfer() async throws {
        let expectation = self.expectation(description: "did resolve erc20 transaction type")
        let qrCode = "aw.app/ethereum:0x89205a3a3b2a69de6dbf7f01ed13b2108b2c43e7/transfer?address=0x8e23ee67d1332ad560396262c48ffbb01f93d052&uint256=1"

        let erc20Token = Token(contract: .init(string: "0x89205a3a3b2a69de6dbf7f01ed13b2108b2c43e7")!, server: .main, name: "erc20", symbol: "erc20", decimals: 6, type: .erc20)
        //NOTE: make sure we have a eth token, base impl resolves it automatically, for test does it manually
        await tokensDataStore.addOrUpdate(with: [.init(erc20Token)])

        transactionTypeSupportable.transactionType = .erc20Token(erc20Token, destination: nil, amount: .notSet)

        provider.buildTransactionType(qrCode: qrCode)
            .sink { result in
                guard case .success(let transactionType) = result else { fatalError() }
                guard case .erc20Token(let token, let destination, let amount) = transactionType else { fatalError() }
                XCTAssertEqual(token, erc20Token)
                XCTAssertNotNil(destination)
                XCTAssertNotNil(amount)
                XCTAssertEqual(transactionType.amount, .amount(1))
                XCTAssertEqual(transactionType.recipient?.contract, AlphaWallet.Address(string: "0x8e23ee67d1332ad560396262c48ffbb01f93d052")!)

                expectation.fulfill()
            }.store(in: &cancelable)

        await fulfillment(of: [expectation], timeout: 3)
    }

    func testScanSmallErc20TransferWhenTokenNeedToResolve() throws {
        let expectation = self.expectation(description: "did resolve erc20 transaction type")
        let qrCode = "aw.app/ethereum:0x89205a3a3b2a69de6dbf7f01ed13b2108b2c43e7/transfer?address=0x8e23ee67d1332ad560396262c48ffbb01f93d052&uint256=1"

        let erc20Token = Token(contract: .init(string: "0x89205a3a3b2a69de6dbf7f01ed13b2108b2c43e7")!, server: .main, name: "erc20", symbol: "erc20", decimals: 6, type: .erc20)
        //NOTE: make sure we have a eth token, base impl resolves it automatically, for test does it manually
        contractDataFetcher.contractData[.init(address: .init(string: "0x89205a3a3b2a69de6dbf7f01ed13b2108b2c43e7")!, server: .main)] = .fungibleTokenComplete(name: "erc20", symbol: "erc20", decimals: 18, value: .zero, tokenType: .erc20)

        transactionTypeSupportable.transactionType = .erc20Token(erc20Token, destination: nil, amount: .notSet)

        provider.buildTransactionType(qrCode: qrCode)
            .sink { result in
                guard case .success(let transactionType) = result else { fatalError() }
                guard case .erc20Token(let token, let destination, let amount) = transactionType else { fatalError() }
                XCTAssertEqual(token, erc20Token)
                XCTAssertNotNil(destination)
                XCTAssertNotNil(amount)
                XCTAssertEqual(transactionType.amount, .amount(1))
                XCTAssertEqual(transactionType.recipient?.contract, AlphaWallet.Address(string: "0x8e23ee67d1332ad560396262c48ffbb01f93d052")!)

                expectation.fulfill()
            }.store(in: &cancelable)

        waitForExpectations(timeout: 3)
    }

    func testScanSmallNonErc20Transfer() throws {
        let expectation = self.expectation(description: "did resolve erc20 transaction type")
        let qrCode = "aw.app/ethereum:0x89205a3a3b2a69de6dbf7f01ed13b2108b2c43e7/transfer?address=0x8e23ee67d1332ad560396262c48ffbb01f93d052&uint256=1"

        //NOTE: make sure we have a eth token, base impl resolves it automatically, for test does it manually
        contractDataFetcher.contractData[.init(address: .init(string: "0x89205a3a3b2a69de6dbf7f01ed13b2108b2c43e7")!, server: .main)] = .fungibleTokenComplete(name: "erc721", symbol: "erc721", decimals: 0, value: .zero, tokenType: .erc721)

        transactionTypeSupportable.transactionType = .prebuilt(.main)

        provider.buildTransactionType(qrCode: qrCode)
            .sink { result in
                guard case .failure(let error) = result else { fatalError() }
                guard case .tokenTypeNotSupported = error else { fatalError() }
                expectation.fulfill()
            }.store(in: &cancelable)

        waitForExpectations(timeout: 3)
    }
}

class DecimalParserTests: XCTestCase {

    func testParseBigIntFromAnyString() throws {
        let parser = DecimalParser()

        XCTAssertEqual(parser.parseAnyDecimal(from: "0.001"), Decimal(double: 0.001))
        XCTAssertEqual(parser.parseAnyDecimal(from: "1"), Decimal(double: 1))
        XCTAssertEqual(parser.parseAnyDecimal(from: "10.23"), Decimal(double: 10.23))
        XCTAssertEqual(parser.parseAnyDecimal(from: "10.230034"), Decimal(double: 10.230034))
        XCTAssertEqual(parser.parseAnyDecimal(from: "10,001"), Decimal(double: 10.001))
        XCTAssertEqual(parser.parseAnyDecimal(from: "1e3"), Decimal(double: 1000))
    }

    func testDecimal() {
        XCTAssertEqual(Decimal(10.23).description, "10.230000000000002048")
        XCTAssertEqual(Decimal(double: 10.23).description, "10.23")
    }
}

final class FakeTransactionTypeSupportable: TransactionTypeSupportable {
    var transactionType: TransactionType = .erc20Token(Token(name: "erc20", symbol: "erc20", type: .erc20), destination: nil, amount: .notSet)
}
