// Copyright © 2018 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet
import Foundation
import AlphaWalletFoundation

class TokenAdaptorTest: XCTestCase {

    func testBundlesAreBrokenIntoContinuousSeatRanges() {
        let date = GeneralisedTime()
        let tokens = [
            TokenScript.Token(tokenIdOrEvent: .tokenId(tokenId: 1), tokenType: TokenType.erc875, index: UInt16(1), name: "Name", symbol: "SYM", status: .available, values: [
                "city": .init(directoryString: "City"),
                "venue": .init(directoryString: "Venue"),
                "match": .init(int: 1),
                "time": .init(generalisedTime: date),
                "numero": .init(int: 1),
                "category": .init(directoryString: "1"),
                "countryA": .init(directoryString: "Team A"),
                "countryB": .init(directoryString: "Team B")
            ]),
            TokenScript.Token(tokenIdOrEvent: .tokenId(tokenId: 2), tokenType: TokenType.erc875, index: UInt16(2), name: "Name", symbol: "SYM", status: .available, values: [
                "city": .init(directoryString: "City"),
                "venue": .init(directoryString: "Venue"),
                "match": .init(int: 1),
                "time": .init(generalisedTime: date),
                "numero": .init(int: 2),
                "category": .init(directoryString: "1"),
                "countryA": .init(directoryString: "Team A"),
                "countryB": .init(directoryString: "Team B")
            ]),
            TokenScript.Token(tokenIdOrEvent: .tokenId(tokenId: 3), tokenType: TokenType.erc875, index: UInt16(3), name: "Name", symbol: "SYM", status: .available, values: [
                "city": .init(directoryString: "City"),
                "venue": .init(directoryString: "Venue"),
                "match": .init(int: 1),
                "time": .init(generalisedTime: date),
                "numero": .init(int: 4),
                "category": .init(directoryString: "1"),
                "countryA": .init(directoryString: "Team A"),
                "countryB": .init(directoryString: "Team B")
            ]),
        ]
        let assetDefinitionStore = AssetDefinitionStore()
        let token = Token(contract: Constants.nullAddress)
        let bundles = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: FakeEventsDataStore()).bundleTestsOnly(tokens: tokens)
        XCTAssertEqual(bundles.count, 2)
    }

    func testBundlesGroupIdenticalSeatIDsTogether() {
        let date = GeneralisedTime()
        let tokens = [
            TokenScript.Token(tokenIdOrEvent: .tokenId(tokenId: 1), tokenType: TokenType.erc875, index: UInt16(1), name: "Name", symbol: "SYM", status: .available, values: [
                "city": .init(directoryString: "City"),
                "venue": .init(directoryString: "Venue"),
                "match": .init(int: 1),
                "time": .init(generalisedTime: date),
                "numero": .init(int: 1),
                "category": .init(directoryString: "1"),
                "countryA": .init(directoryString: "Team A"),
                "countryB": .init(directoryString: "Team B")
            ]),
            TokenScript.Token(tokenIdOrEvent: .tokenId(tokenId: 2), tokenType: TokenType.erc875, index: UInt16(2), name: "Name", symbol: "SYM", status: .available, values: [
                "city": .init(directoryString: "City"),
                "venue": .init(directoryString: "Venue"),
                "match": .init(int: 1),
                "time": .init(generalisedTime: date),
                "numero": .init(int: 2),
                "category": .init(directoryString: "1"),
                "countryA": .init(directoryString: "Team A"),
                "countryB": .init(directoryString: "Team B")
            ]),
            TokenScript.Token(tokenIdOrEvent: .tokenId(tokenId: 3), tokenType: TokenType.erc875, index: UInt16(3), name: "Name", symbol: "SYM", status: .available, values: [
                "city": .init(directoryString: "City"),
                "venue": .init(directoryString: "Venue"),
                "match": .init(int: 1),
                "time": .init(generalisedTime: date),
                "numero": .init(int: 4),
                "category": .init(directoryString: "1"),
                "countryA": .init(directoryString: "Team A"),
                "countryB": .init(directoryString: "Team B")
            ]),
            TokenScript.Token(tokenIdOrEvent: .tokenId(tokenId: 4), tokenType: TokenType.erc875, index: UInt16(4), name: "Name", symbol: "SYM", status: .available, values: [
                "city": .init(directoryString: "City"),
                "venue": .init(directoryString: "Venue"),
                "match": .init(int: 1),
                "time": .init(generalisedTime: date),
                "numero": .init(int: 2),
                "category": .init(directoryString: "1"),
                "countryA": .init(directoryString: "Team A"),
                "countryB": .init(directoryString: "Team B")
            ])
        ]
        let assetDefinitionStore = AssetDefinitionStore()
        let token = Token(contract: Constants.nullAddress)

        let bundles = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: FakeEventsDataStore()).bundleTestsOnly(tokens: tokens)
        XCTAssertEqual(bundles.count, 2)
    }

}
