//
//  Token.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/25/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import AlphaWalletCore
import BigInt
import WebKit

extension TokenScript {
    public struct Token: Hashable {
        public static func == (lhs: Token, rhs: Token) -> Bool {
            return lhs.id == rhs.id
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(tokenIdOrEvent.tokenId)
            hasher.combine(tokenType)
            hasher.combine(index)
            hasher.combine(name)
            hasher.combine(symbol)
            hasher.combine(status)
            hasher.combine(values)
        }

        public enum Status {
            case available, sold, redeemed, forSale, transferred, pending, availableButDataUnavailable
        }

        public var id: TokenId {
            tokenIdOrEvent.tokenId
        }
        public let tokenIdOrEvent: TokenIdOrEvent
        public let tokenType: TokenType
        public let index: UInt16
        public let name: String
        public let symbol: String
        public let status: Status
        public let values: [AttributeId: AssetAttributeSyntaxValue]

        public var value: Int? {
            values.valueIntValue.flatMap { String($0) }.flatMap { Int($0) }
        }

        public static var empty: Token {
            return Token(
                    tokenIdOrEvent: .tokenId(tokenId: Constants.nullTokenIdBigUInt),
                    tokenType: TokenType.erc875,
                    index: 0,
                    name: "Tokens",
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
        public var isSpawnableMeetupContract: Bool {
            return values["expired"] != nil && values["locality"] != nil && values["building"] != nil
        }
        public init(tokenIdOrEvent: TokenIdOrEvent, tokenType: TokenType, index: UInt16, name: String, symbol: String, status: Status, values: [AttributeId: AssetAttributeSyntaxValue]) {
            self.tokenIdOrEvent = tokenIdOrEvent
            self.tokenType = tokenType
            self.index = index
            self.name = name
            self.symbol = symbol
            self.status = status
            self.values = values
        }
    }
}

public func generateContainerCssId(forTokenId tokenId: TokenId) -> String {
    return "token-card-\(tokenId)"
}

public func wrapWithHtmlViewport(html: String, style: String, forTokenId tokenId: TokenId) -> String {
    if html.isEmpty {
        return ""
    } else {
        let containerCssId = generateContainerCssId(forTokenId: tokenId)
        return """
               <html>
               <head>
               <meta name="viewport" content="width=device-width, initial-scale=1,  maximum-scale=1, shrink-to-fit=no">
               \(style)
               </head>
               <body>
               <div id="\(containerCssId)" class="token-card">
               \(html)
               </div>
               </body>
               </html>
               """
    }
}
