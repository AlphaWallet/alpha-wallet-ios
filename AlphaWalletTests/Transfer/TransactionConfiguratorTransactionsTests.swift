//
//  TransactionConfiguratorTests.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 12.01.2021.
//

import XCTest
@testable import AlphaWallet
import BigInt
import AlphaWalletFoundation

class TransactionConfiguratorTransactionsTests: XCTestCase {

    func testDAppRecipientAddress() throws {
        let address = AlphaWallet.Address(string: "0x1000000000000000000000000000000000000000")!
        let walletConnectTransaction = WalletConnectTransaction(contract: address)

        let transaction = try TransactionType.prebuilt(.main).buildAnyDappTransaction(walletConnectTransaction: walletConnectTransaction)

        let configurator = TransactionConfigurator(
            session: .make(),
            transaction: transaction,
            networkService: FakeNetworkService(),
            tokensService: WalletDataProcessingPipeline.make(wallet: .make(), server: .main).pipeline,
            configuration: .sendFungiblesTransaction(confirmType: .signThenSend))

        XCTAssertEqual(configurator.toAddress, address)
    }

    func testERC721TokenRecipientAddress() {
        let address = AlphaWallet.Address(string: "0x1000000000000000000000000000000000000000")!
        let address2 = AlphaWallet.Address(string: "0x1000000000000000000000000000000000000002")!
        let token = Token(contract: address, server: .main, value: "0", type: .erc721)

        let transaction = UnconfirmedTransaction(transactionType: .erc721Token(token, tokenHolders: []), value: BigUInt(0), recipient: address2, contract: address)

        let configurator = TransactionConfigurator(
            session: .make(),
            transaction: transaction,
            networkService: FakeNetworkService(),
            tokensService: WalletDataProcessingPipeline.make(wallet: .make(), server: .main).pipeline,
            configuration: .sendFungiblesTransaction(confirmType: .signThenSend))

        XCTAssertEqual(configurator.toAddress, address)
        XCTAssertNotEqual(configurator.toAddress, transaction.recipient)
    }

    func testNativeCryptoTokenRecipientAddress() {
        let address = AlphaWallet.Address(string: "0x1000000000000000000000000000000000000000")!
        let token = Token(contract: address, server: .main, value: "0", type: .nativeCryptocurrency)

        let transaction = UnconfirmedTransaction(transactionType: .nativeCryptocurrency(token, destination: nil, amount: .notSet), value: BigUInt(0), recipient: address, contract: nil)

        let configurator = TransactionConfigurator(
            session: .make(),
            transaction: transaction,
            networkService: FakeNetworkService(),
            tokensService: WalletDataProcessingPipeline.make(wallet: .make(), server: .main).pipeline,
            configuration: .sendFungiblesTransaction(confirmType: .signThenSend))

        XCTAssertEqual(configurator.toAddress, address)
        XCTAssertNotEqual(configurator.toAddress, transaction.contract)
    }
}
