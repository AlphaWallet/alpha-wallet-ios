//
//  TokenGroupIdentifierTest.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 25/3/22.
//

import XCTest
@testable import AlphaWallet

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
        let tokenObject = TokenObject()
        // match address and id in contract
        tokenObject.contract = "0xF0A5717Ec0883eE56438932b0fe4A20822735fBa"
        tokenObject.chainId = 42161
        XCTAssertEqual(tokenGroupIdentifier!.identify(tokenObject: tokenObject), TokenGroup.defi)
        // match address only
        tokenObject.contract = "0xF0A5717Ec0883eE56438932b0fe4A20822735fBa"
        tokenObject.chainId = 4216154
        XCTAssertNotEqual(tokenGroupIdentifier!.identify(tokenObject: tokenObject), TokenGroup.defi)
        // match id only
        tokenObject.contract = "0xF0A5717Ec0883eE56438932b0fF4A20822735fBB"
        tokenObject.chainId = 42161
        XCTAssertNotEqual(tokenGroupIdentifier!.identify(tokenObject: tokenObject), TokenGroup.defi)
        // match nothing
        tokenObject.contract = "0xE0A5717Ec0883eE56438932b0fF4A20822735fBB"
        tokenObject.chainId = 42161234
        XCTAssertNotEqual(tokenGroupIdentifier!.identify(tokenObject: tokenObject), TokenGroup.defi)
    }

    func testDetectGoverance() throws {
        let tokenGroupIdentifier: TokenGroupIdentifierProtocol? = TokenGroupIdentifier.identifier(fromFileName: "tokens")
        XCTAssert(tokenGroupIdentifier != nil)
        let tokenObject = TokenObject()
        // match address and id in contract
        tokenObject.contract = "0xaaA62D9584Cbe8e4D68A43ec91BfF4fF1fAdB202"
        tokenObject.chainId = 42161
        XCTAssertEqual(tokenGroupIdentifier!.identify(tokenObject: tokenObject), TokenGroup.governance)
        // match address only
        tokenObject.contract = "0xaaA62D9584Cbe8e4D68A43ec91BfF4fF1fAdB202"
        tokenObject.chainId = 4216154
        XCTAssertNotEqual(tokenGroupIdentifier!.identify(tokenObject: tokenObject), TokenGroup.governance)
        // match id only
        tokenObject.contract = "0xF0A5717Ec0883eE56438932b0fF4A20822735fBB"
        tokenObject.chainId = 42161
        XCTAssertNotEqual(tokenGroupIdentifier!.identify(tokenObject: tokenObject), TokenGroup.governance)
        // match nothing
        tokenObject.contract = "0xE0A5717Ec0883eE56438932b0fF4A20822735fBB"
        tokenObject.chainId = 42161234
        XCTAssertNotEqual(tokenGroupIdentifier!.identify(tokenObject: tokenObject), TokenGroup.governance)
    }

    func testDetectAssets() throws {
        let tokenGroupIdentifier: TokenGroupIdentifierProtocol? = TokenGroupIdentifier.identifier(fromFileName: "tokens")
        XCTAssert(tokenGroupIdentifier != nil)
        let tokenObject = TokenObject()
        // match address and id in contract
        tokenObject.contract = "0xfc82bb4ba86045af6f327323a46e80412b91b27d"
        tokenObject.chainId = 1
        XCTAssertEqual(tokenGroupIdentifier!.identify(tokenObject: tokenObject), TokenGroup.assets)
        // match groupless contract
        tokenObject.contract = "0x3b42fd538597fd049648c9f017208bf712195b73"
        tokenObject.chainId = 250
        XCTAssertEqual(tokenGroupIdentifier!.identify(tokenObject: tokenObject), TokenGroup.assets)
        // match contact and chain id not in json file
        tokenObject.contract = "this is not a contract"
        tokenObject.chainId = 555
        XCTAssertEqual(tokenGroupIdentifier!.identify(tokenObject: tokenObject), TokenGroup.assets)
    }

    func testDetectCollectible() throws {
        let tokenGroupIdentifier: TokenGroupIdentifierProtocol? = TokenGroupIdentifier.identifier(fromFileName: "tokens")
        XCTAssert(tokenGroupIdentifier != nil)
        let tokenObject = TokenObject()
        tokenObject.type = .erc721
        XCTAssertEqual(tokenGroupIdentifier!.identify(tokenObject: tokenObject), TokenGroup.collectibles)
        tokenObject.type = .erc1155
        XCTAssertEqual(tokenGroupIdentifier!.identify(tokenObject: tokenObject), TokenGroup.collectibles)
        tokenObject.type = .erc875
        XCTAssertNotEqual(tokenGroupIdentifier!.identify(tokenObject: tokenObject), TokenGroup.collectibles)
    }

}
