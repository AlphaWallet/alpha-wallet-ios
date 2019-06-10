// Copyright © 2018 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet
import Foundation

class TokenAdaptorTest: XCTestCase {

    func testBundlesAreBrokenIntoContinuousSeatRanges() {
        let date = GeneralisedTime()
        let tokens = [
            Token(id: .init(1), index: UInt16(1), name: "Name", symbol: "SYM", status: .available, values: [
                "city": .init(directoryString: "City"),
                "venue": .init(directoryString: "Venue"),
                "match": .init(int: 1),
                "time": .init(generalisedTime: date),
                "numero": .init(int: 1),
                "category": .init(directoryString: "1"),
                "countryA": .init(directoryString: "Team A"),
                "countryB": .init(directoryString: "Team B")
            ]),
            Token(id: .init(2), index: UInt16(2), name: "Name", symbol: "SYM", status: .available, values: [
                "city": .init(directoryString: "City"),
                "venue": .init(directoryString: "Venue"),
                "match": .init(int: 1),
                "time": .init(generalisedTime: date),
                "numero": .init(int: 2),
                "category": .init(directoryString: "1"),
                "countryA": .init(directoryString: "Team A"),
                "countryB": .init(directoryString: "Team B")
            ]),
            Token(id: .init(3), index: UInt16(3), name: "Name", symbol: "SYM", status: .available, values: [
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
        let token = TokenObject()
        token.contract = Constants.nullAddress
        let bundles = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore).bundle(tokens: tokens)
        XCTAssertEqual(bundles.count, 2)
    }

    func testBundlesGroupIdenticalSeatIDsTogether() {
        let date = GeneralisedTime()
        let tokens = [
            Token(id: .init(1), index: UInt16(1), name: "Name", symbol: "SYM", status: .available, values: [
                "city": .init(directoryString: "City"),
                "venue": .init(directoryString: "Venue"),
                "match": .init(int: 1),
                "time": .init(generalisedTime: date),
                "numero": .init(int: 1),
                "category": .init(directoryString: "1"),
                "countryA": .init(directoryString: "Team A"),
                "countryB": .init(directoryString: "Team B")
            ]),
            Token(id: .init(2), index: UInt16(2), name: "Name", symbol: "SYM", status: .available, values: [
                "city": .init(directoryString: "City"),
                "venue": .init(directoryString: "Venue"),
                "match": .init(int: 1),
                "time": .init(generalisedTime: date),
                "numero": .init(int: 2),
                "category": .init(directoryString: "1"),
                "countryA": .init(directoryString: "Team A"),
                "countryB": .init(directoryString: "Team B")
            ]),
            Token(id: .init(3), index: UInt16(3), name: "Name", symbol: "SYM", status: .available, values: [
                "city": .init(directoryString: "City"),
                "venue": .init(directoryString: "Venue"),
                "match": .init(int: 1),
                "time": .init(generalisedTime: date),
                "numero": .init(int: 4),
                "category": .init(directoryString: "1"),
                "countryA": .init(directoryString: "Team A"),
                "countryB": .init(directoryString: "Team B")
            ]),
            Token(id: .init(4), index: UInt16(4), name: "Name", symbol: "SYM", status: .available, values: [
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
        let token = TokenObject()
        token.contract = Constants.nullAddress
        let bundles = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore).bundle(tokens: tokens)
        XCTAssertEqual(bundles.count, 2)
    }

}
