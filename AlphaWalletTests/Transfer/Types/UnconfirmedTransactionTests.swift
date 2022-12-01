//
//  UnconfirmedTransactionTests.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 01.12.2022.
//

import XCTest
@testable import AlphaWallet
import BigInt
import AlphaWalletFoundation
import AlphaWalletWeb3

class UnconfirmedTransactionTests: XCTestCase {

    func testErc20Transfer() throws {
        let amount = BigUInt(1)
        let contract = AlphaWallet.Address(uncheckedAgainstNullAddress: "0x0000000000000000000000000000000000000009")!
        let recipient = AlphaWallet.Address(uncheckedAgainstNullAddress: "0x0000000000000000000000000000000000000001")!
        let token = Token(contract: contract, name: "Erc20", decimals: 6, type: .erc20)

        let transaction = try TransactionType(fungibleToken: token, amount: amount.description).buildSendErc20Token(recipient: recipient, amount: amount)

        XCTAssertEqual(transaction.contract, contract)
        XCTAssertEqual(transaction.recipient, recipient)
        
        guard let data = transaction.data else { fatalError() }
        guard let functionalCall = DecodedFunctionCall(data: data) else { fatalError() }
        guard case .erc20Transfer(let _recipient, let _amount) = functionalCall.type else { fatalError() }

        XCTAssertEqual(_recipient, recipient)
        XCTAssertEqual(_amount, amount)
    }

    func testNativeCryptoTransfer() throws {
        let amount = EtherNumberFormatter.plain.number(from: "1", units: .ether)!
        let contract = AlphaWallet.Address(uncheckedAgainstNullAddress: "0x0000000000000000000000000000000000000009")!
        let recipient = AlphaWallet.Address(uncheckedAgainstNullAddress: "0x0000000000000000000000000000000000000001")!
        let token = Token(contract: contract, name: "ETH", decimals: 18, type: .nativeCryptocurrency)

        let transaction = try TransactionType(fungibleToken: token, amount: amount.description).buildSendNativeCryptocurrency(recipient: recipient, amount: BigUInt(amount))

        XCTAssertEqual(transaction.contract, nil)
        XCTAssertEqual(transaction.recipient, recipient)
        XCTAssertEqual(transaction.data, Data())
    }

    func testErc721Transfer() throws {
        let contract = AlphaWallet.Address(uncheckedAgainstNullAddress: "0x0000000000000000000000000000000000000009")!
        let recipient = AlphaWallet.Address(uncheckedAgainstNullAddress: "0x0000000000000000000000000000000000000001")!
        let token = Token(contract: contract, name: "Erc721", decimals: 0, type: .erc721)

        let tokenHolders = [TokenHolder(tokens: [
            TokenScript.Token(tokenIdOrEvent: .tokenId(tokenId: "1"), tokenType: .erc721, index: 0, name: "Name", symbol: "Symbol", status: .available, values: [:])
        ], contractAddress: contract, hasAssetDefinition: false).select(with: .allFor(tokenId: "1"))]

        let transaction = try TransactionType(nonFungibleToken: token, tokenHolders: tokenHolders).buildSendErc721Token(recipient: recipient, account: Constants.nullAddress)

        XCTAssertEqual(transaction.contract, contract)
        XCTAssertEqual(transaction.recipient, recipient)

        guard let data = transaction.data else { fatalError() }
        let web3 = try Web3.instance(for: .main, timeout: 0)
        let _contract = try Web3.Contract(web3: web3, abiString: AlphaWallet.Ethereum.ABI.erc721String)
        guard let result = _contract.decodeInputData(data) else { fatalError() }

        XCTAssertEqual((result["tokenId"] as? BigUInt), "1")
        XCTAssertEqual((result["from"] as? AlphaWalletWeb3.EthereumAddress)?.description, Constants.nullAddress.eip55String)
        XCTAssertEqual((result["to"] as? AlphaWalletWeb3.EthereumAddress)?.description, recipient.eip55String)
    }
}
