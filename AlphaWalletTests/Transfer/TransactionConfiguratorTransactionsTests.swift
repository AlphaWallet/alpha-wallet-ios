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
        let walletConnectTransaction = WalletConnectTransaction(to: address)

        let transaction = try TransactionType.prebuilt(.main).buildAnyDappTransaction(walletConnectTransaction: walletConnectTransaction)
        let analytics = FakeAnalyticsService()

        let configurator = TransactionConfigurator(
            session: .make(),
            analytics: analytics,
            transaction: transaction,
            networkService: FakeNetworkService())

        XCTAssertEqual(configurator.toAddress, address)
    }

    func testERC721TokenRecipientAddress() {
        let address = AlphaWallet.Address(string: "0x1000000000000000000000000000000000000000")!
        let address2 = AlphaWallet.Address(string: "0x1000000000000000000000000000000000000002")!
        let token = Token(contract: address, server: .main, value: "0", type: .erc721)
        let analytics = FakeAnalyticsService()

        let transaction = UnconfirmedTransaction(transactionType: .erc721Token(token, tokenHolders: []), value: BigUInt(0), recipient: address2, contract: address, data: nil)

        let configurator = TransactionConfigurator(
            session: .make(),
            analytics: analytics,
            transaction: transaction,
            networkService: FakeNetworkService())

        XCTAssertEqual(configurator.toAddress, address)
        XCTAssertNotEqual(configurator.toAddress, transaction.recipient)
    }

    func testNativeCryptoTokenRecipientAddress() {
        let address = AlphaWallet.Address(string: "0x1000000000000000000000000000000000000000")!
        let token = Token(contract: address, server: .main, value: "0", type: .nativeCryptocurrency)
        let analytics = FakeAnalyticsService()

        let transaction = UnconfirmedTransaction(transactionType: .nativeCryptocurrency(token, destination: nil, amount: .notSet), value: BigUInt(0), recipient: address, contract: nil, data: nil)

        let configurator = TransactionConfigurator(
            session: .make(),
            analytics: analytics,
            transaction: transaction,
            networkService: FakeNetworkService())

        XCTAssertEqual(configurator.toAddress, address)
        XCTAssertNotEqual(configurator.toAddress, transaction.contract)
    }
}
