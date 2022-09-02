//
//  TokenGroupIdentifierTest.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 25/3/22.
//

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class TokenGroupIdentifierTest: XCTestCase {

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testReadingExistingFile() throws {
        let reader: TokenGroupIdentifierProtocol? = TokenGroupIdentifier.identifier(fromFileName: "tokens")
        XCTAssertNotNil(reader)
    }

    func testReadingExistingNonJsonFile() throws {
        let reader: TokenGroupIdentifierProtocol? = TokenGroupIdentifier.identifier(fromFileName: "schema")
        XCTAssertNil(reader)
    }

    func testReadingNonExistingFile() throws {
        let reader: TokenGroupIdentifierProtocol? = TokenGroupIdentifier.identifier(fromFileName: "Not present at all")
        XCTAssertNil(reader)
    }

    func testDetectDefi() throws {
        let tokenGroupIdentifier: TokenGroupIdentifierProtocol? = TokenGroupIdentifier.identifier(fromFileName: "tokens")
        XCTAssert(tokenGroupIdentifier != nil)
        // match address and id in contract
        let t1 = Token(contract: AlphaWallet.Address(string: "0xF0A5717Ec0883eE56438932b0fe4A20822735fBa")!, server: RPCServer.custom(chainId: 42161))
        XCTAssertEqual(tokenGroupIdentifier!.identify(token: t1), TokenGroup.defi)
        // match address only
        let t2 = Token(contract: AlphaWallet.Address(string: "0xF0A5717Ec0883eE56438932b0fe4A20822735fBa")!, server: RPCServer.custom(chainId: 4216154))
        XCTAssertNotEqual(tokenGroupIdentifier!.identify(token: t2), TokenGroup.defi)
        // match id only
        let t3 = Token(contract: AlphaWallet.Address(string: "0xF0A5717Ec0883eE56438932b0fF4A20822735fBB")!, server: RPCServer.custom(chainId: 42161))
        XCTAssertNotEqual(tokenGroupIdentifier!.identify(token: t3), TokenGroup.defi)
        // match nothing
        let t4 = Token(contract: AlphaWallet.Address(string: "0xE0A5717Ec0883eE56438932b0fF4A20822735fBB")!, server: RPCServer.custom(chainId: 42161234))
        XCTAssertNotEqual(tokenGroupIdentifier!.identify(token: t4), TokenGroup.defi)
    }

    func testDetectGoverance() throws {
        let tokenGroupIdentifier: TokenGroupIdentifierProtocol? = TokenGroupIdentifier.identifier(fromFileName: "tokens")
        XCTAssert(tokenGroupIdentifier != nil)
        // match address and id in contract
        let t1 = Token(contract: AlphaWallet.Address(string: "0xaaA62D9584Cbe8e4D68A43ec91BfF4fF1fAdB202")!, server: RPCServer.custom(chainId: 42161))
        XCTAssertEqual(tokenGroupIdentifier!.identify(token: t1), TokenGroup.governance)
        // match address only
        let t2 = Token(contract: AlphaWallet.Address(string: "0xaaA62D9584Cbe8e4D68A43ec91BfF4fF1fAdB202")!, server: RPCServer.custom(chainId: 4216154))
        XCTAssertNotEqual(tokenGroupIdentifier!.identify(token: t2), TokenGroup.governance)
        // match id only
        let t3 = Token(contract: AlphaWallet.Address(string: "0xF0A5717Ec0883eE56438932b0fF4A20822735fBB")!, server: RPCServer.custom(chainId: 42161))
        XCTAssertNotEqual(tokenGroupIdentifier!.identify(token: t3), TokenGroup.governance)
        // match nothing
        let t4 = Token(contract: AlphaWallet.Address(string: "0xE0A5717Ec0883eE56438932b0fF4A20822735fBB")!, server: RPCServer.custom(chainId: 42161234))
        XCTAssertNotEqual(tokenGroupIdentifier!.identify(token: t4), TokenGroup.governance)
    }

    func testDetectAssets() throws {
        let tokenGroupIdentifier: TokenGroupIdentifierProtocol? = TokenGroupIdentifier.identifier(fromFileName: "tokens")
        XCTAssert(tokenGroupIdentifier != nil)
        let t1 = Token(contract: AlphaWallet.Address(string: "0xfc82bb4ba86045af6f327323a46e80412b91b27d")!, server: RPCServer.custom(chainId: 1))
        XCTAssertEqual(tokenGroupIdentifier!.identify(token: t1), TokenGroup.assets)
        // match groupless contract
        let t2 = Token(contract: AlphaWallet.Address(string: "0x3b42fd538597fd049648c9f017208bf712195b73")!, server: RPCServer.custom(chainId: 250))
        XCTAssertEqual(tokenGroupIdentifier!.identify(token: t2), TokenGroup.assets)
        // match contact and chain id not in json file
        let t3 = Token(contract: Constants.nullAddress, server: RPCServer.custom(chainId: 555))
        XCTAssertEqual(tokenGroupIdentifier!.identify(token: t3), TokenGroup.assets)
    }

    func testDetectCollectible() throws {
        let tokenGroupIdentifier: TokenGroupIdentifierProtocol? = TokenGroupIdentifier.identifier(fromFileName: "tokens")
        XCTAssert(tokenGroupIdentifier != nil)
        let t1 = Token(type: .erc721)
        XCTAssertEqual(tokenGroupIdentifier!.identify(token: t1), TokenGroup.collectibles)
        let t2 = Token(type: .erc1155)
        XCTAssertEqual(tokenGroupIdentifier!.identify(token: t2), TokenGroup.collectibles)
        let t3 = Token(type: .erc875)
        XCTAssertNotEqual(tokenGroupIdentifier!.identify(token: t3), TokenGroup.collectibles)
    }

}
