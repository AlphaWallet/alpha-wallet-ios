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
        let requester = DAppRequester(title: "", url: nil)
        let token = Token(server: .main, value: "", type: .erc20)
        let address = AlphaWallet.Address(string: "0x1000000000000000000000000000000000000000")!
        let bridge = RawTransactionBridge(to: address)
        let transaction = UnconfirmedTransaction(transactionType: .dapp(token, requester), bridge: bridge)
        let analytics = FakeAnalyticsService()

        let configurator = try TransactionConfigurator(session: .make(), analytics: analytics, transaction: transaction)

        XCTAssertEqual(configurator.toAddress, address)
    }

    func testERC721TokenRecipientAddress() throws {
        let address = AlphaWallet.Address(string: "0x1000000000000000000000000000000000000000")!
        let address2 = AlphaWallet.Address(string: "0x1000000000000000000000000000000000000002")!
        let token = Token(contract: address, server: .main, value: "0", type: .erc721)
        let analytics = FakeAnalyticsService()

        let transaction = UnconfirmedTransaction(transactionType: .erc721Token(token, tokenHolders: []), value: BigInt(0), recipient: address2, contract: address, data: nil, tokenId: BigUInt("0"))

        let configurator = try TransactionConfigurator(session: .make(), analytics: analytics, transaction: transaction)

        XCTAssertEqual(configurator.toAddress, address)
        XCTAssertNotEqual(configurator.toAddress, transaction.recipient)
    }

    func testNativeCryptoTokenRecipientAddress() throws {
        let address = AlphaWallet.Address(string: "0x1000000000000000000000000000000000000000")!
        let token = Token(contract: address, server: .main, value: "0", type: .erc721)
        let analytics = FakeAnalyticsService()

        let transaction = UnconfirmedTransaction(transactionType: .nativeCryptocurrency(token, destination: nil, amount: nil), value: BigInt(0), recipient: address, contract: nil, data: nil, tokenId: BigUInt("0"))

        let configurator = try TransactionConfigurator(session: .make(), analytics: analytics, transaction: transaction)

        XCTAssertEqual(configurator.toAddress, address)
        XCTAssertNotEqual(configurator.toAddress, transaction.contract)
    }
}
