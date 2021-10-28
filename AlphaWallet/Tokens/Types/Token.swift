//
//  Token.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/25/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import BigInt

struct Token: Hashable {
    static func == (lhs: Token, rhs: Token) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(tokenIdOrEvent.tokenId)
        hasher.combine(tokenType)
        hasher.combine(index)
        hasher.combine(name)
        hasher.combine(symbol)
        hasher.combine(status)
        hasher.combine(values)
    }

    enum Status {
        case available, sold, redeemed, forSale, transferred, pending, availableButDataUnavailable
    }

    var id: TokenId {
        tokenIdOrEvent.tokenId
    }
    let tokenIdOrEvent: TokenIdOrEvent
    let tokenType: TokenType
    let index: UInt16
    let name: String
    let symbol: String
    let status: Status
    let values: [AttributeId: AssetAttributeSyntaxValue]

    var value: Int? {
        values.valueIntValue.flatMap { String($0) }.flatMap { Int($0) }
    }

    static var empty: Token {
        return Token(
                tokenIdOrEvent: .tokenId(tokenId: Constants.nullTokenIdBigUInt),
                tokenType: TokenType.erc875,
                index: 0,
                name: R.string.localizable.tokensTitlecase(),
                symbol: "",
                status: .available,
                values: [
                    "locality": .init(defaultValueWithSyntax: .directoryString),
                    "venue": .init(defaultValueWithSyntax: .directoryString),
                    "match": .init(defaultValueWithSyntax: .integer),
                    "time": .init(defaultValueWithSyntax: .generalisedTime),
                    "numero": .init(defaultValueWithSyntax: .integer),
                    "category": .init(defaultValueWithSyntax: .directoryString),
                    "countryA": .init(defaultValueWithSyntax: .directoryString),
                    "countryB": .init(defaultValueWithSyntax: .directoryString)
                ]
        )
    }

    //TODO have a better way to test for spawnable meetup contracts
    var isSpawnableMeetupContract: Bool {
        return values["expired"] != nil && values["locality"] != nil && values["building"] != nil
    }
}
