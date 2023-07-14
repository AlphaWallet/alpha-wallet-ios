//
//  UnconfirmedTransactionTests.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 01.12.2022.
//

import XCTest
@testable import AlphaWallet
@testable import AlphaWalletWeb3
import AlphaWalletFoundation
import BigInt

class UnconfirmedTransactionTests: XCTestCase {

    func testDecodeEmptyData() throws {
        XCTAssertNil(DecodedFunctionCall(data: Data()))
    }

    func testErc20Transfer() throws {
        let amount = BigUInt(1)
        let contract = AlphaWallet.Address(uncheckedAgainstNullAddress: "0x0000000000000000000000000000000000000009")!
        let recipient = AlphaWallet.Address(uncheckedAgainstNullAddress: "0x0000000000000000000000000000000000000001")!
        let token = Token(contract: contract, name: "Erc20", decimals: 6, type: .erc20)

        let transaction = try TransactionType(fungibleToken: token, amount: .amount(1)).buildSendErc20Token(recipient: recipient, amount: amount)

        XCTAssertEqual(transaction.contract, contract)
        XCTAssertEqual(transaction.recipient, recipient)

        guard let functionalCall = DecodedFunctionCall(data: transaction.data) else { fatalError() }
        guard case .erc20Transfer(let _recipient, let _amount) = functionalCall.type else { fatalError() }

        XCTAssertEqual(_recipient, recipient)
        XCTAssertEqual(_amount, amount)

        let _contract = try Contract(abi: AlphaWallet.Ethereum.ABI.erc20)
        guard let result = _contract.decodeInputData(transaction.data) else { fatalError() }

        XCTAssertEqual(result.name, "transfer")
        XCTAssertEqual((result.params?["tokens"] as? BigUInt), amount)
        XCTAssertEqual((result.params?["to"] as? AlphaWalletWeb3.EthereumAddress)?.description, recipient.eip55String)
    }

    func testNativeCryptoTransfer() throws {
        let amount = EtherNumberFormatter.plain.number(from: "1", units: .ether)!
        let contract = AlphaWallet.Address(uncheckedAgainstNullAddress: "0x0000000000000000000000000000000000000009")!
        let recipient = AlphaWallet.Address(uncheckedAgainstNullAddress: "0x0000000000000000000000000000000000000001")!
        let token = Token(contract: contract, name: "ETH", decimals: 18, type: .nativeCryptocurrency)

        let transaction = try TransactionType(fungibleToken: token, amount: .amount(1)).buildSendNativeCryptocurrency(recipient: recipient, amount: BigUInt(amount))

        XCTAssertEqual(transaction.contract, nil)
        XCTAssertEqual(transaction.recipient, recipient)
        XCTAssertEqual(transaction.data, Data())
    }

    func testErc721Transfer() throws {
        let contract = AlphaWallet.Address(uncheckedAgainstNullAddress: "0x0000000000000000000000000000000000000009")!
        let recipient = AlphaWallet.Address(uncheckedAgainstNullAddress: "0x0000000000000000000000000000000000000001")!
        let token = Token(contract: contract, name: "Erc721", decimals: 0, type: .erc721)
        let tokenId: BigUInt = "1"

        let tokenHolders = [TokenHolder(tokens: [
            TokenScript.Token(
                tokenIdOrEvent: .tokenId(tokenId: tokenId),
                tokenType: .erc721,
                index: 0,
                name: "Name",
                symbol: "Symbol",
                status: .available,
                values: [:])
        ], contractAddress: contract, hasAssetDefinition: false).select(with: .allFor(tokenId: tokenId))]

        let transaction = try TransactionType(nonFungibleToken: token, tokenHolders: tokenHolders).buildSendErc721Token(recipient: recipient, account: Constants.nullAddress)

        XCTAssertEqual(transaction.contract, contract)
        XCTAssertEqual(transaction.recipient, recipient)

        let _contract = try Contract(abi: AlphaWallet.Ethereum.ABI.erc721)
        guard let result = _contract.decodeInputData(transaction.data) else { fatalError() }

        XCTAssertEqual(result.signature, "42842e0e")
        XCTAssertEqual(result.name, "safeTransferFrom")

        XCTAssertEqual((result.params?["tokenId"] as? BigUInt), "1")
        XCTAssertEqual((result.params?["from"] as? AlphaWalletWeb3.EthereumAddress)?.description, Constants.nullAddress.eip55String)
        XCTAssertEqual((result.params?["to"] as? AlphaWalletWeb3.EthereumAddress)?.description, recipient.eip55String)
    }
}

extension EthereumAddress: CustomStringConvertible {
    public var description: String {
        address
    }
}
