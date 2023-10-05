//
//  TokenHolder.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/25/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import AlphaWalletCore
import AlphaWalletOpenSea
import AlphaWalletTokenScript
import BigInt

public enum TokenHolderSelectionStrategy {
    case all
    case token(tokenId: TokenId, amount: Int)
    case allFor(tokenId: TokenId)
}

public enum TokenHolderUnselectionStrategy {
    case all
    case token(token: TokenId)
}

extension TokenHolder {

    public func isSelected(tokenId: TokenId) -> Bool {
        selections.contains { $0.tokenId == tokenId }
    }

    public var totalSelectedCount: Int {
        var sum: BigUInt = 0
        for each in selections {
            sum += each.value
        }

        return Int(sum)
    }

    public func selectedCount(tokenId: TokenId) -> Int? {
        selections.first(where: { $0.tokenId == tokenId }).flatMap { Int($0.value) }
    }

    @discardableResult public func select(with strategy: TokenHolderSelectionStrategy) -> Self {
        switch strategy {
        case .allFor(let tokenId):
            guard let token = token(tokenId: tokenId) else { return self }
            select(with: .token(tokenId: tokenId, amount: token.value ?? 0))
        case .all:
            selections = tokens.compactMap {
                //TODO need to make sure the available `amount` is set previously  so we can use it here
                if let value = $0.value {
                    return TokenSelection(tokenId: $0.id, value: BigUInt(value))
                } else {
                    return nil
                }
            }
        case .token(let tokenId, let newAmount):
            guard tokens.contains(where: { $0.id == tokenId }) else { return self }
            if let index = selections.firstIndex(where: { $0.tokenId == tokenId }) {
                if newAmount > 0 {
                    selections[index] = TokenSelection(tokenId: tokenId, value: BigUInt(newAmount))
                } else {
                    selections.remove(at: index)
                }
            } else {
                guard newAmount > 0 else { return self }
                selections.append(TokenSelection(tokenId: tokenId, value: BigUInt(newAmount)))
            }
        }

        return self
    }

    public func unselect(with strategy: TokenHolderSelectionStrategy) {
        switch strategy {
        case .all:
            selections = []
        case .allFor(let tokenId):
            guard let token = token(tokenId: tokenId) else { return }
            unselect(with: .token(tokenId: tokenId, amount: token.value ?? 0))
        case .token(let tokenId, let amount):
            if let index = selections.firstIndex(where: { $0.tokenId == tokenId }) {
                selections[index] = TokenSelection(tokenId: tokenId, value: BigUInt(amount))
            } else {
                // no-op
            }
        }
    }
}

public enum TokenHolderType {
    case collectible
    case single
}

public class TokenHolder: TokenHolderProtocol, Hashable {
    public static func == (lhs: TokenHolder, rhs: TokenHolder) -> Bool {
        return lhs.tokenId == rhs.tokenId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(tokens)
        hasher.combine(contractAddress.eip55String)
        hasher.combine(selections)
    }

    public let tokens: [TokenScript.Token]
    public let contractAddress: AlphaWallet.Address
    public let hasAssetDefinition: Bool

    public private (set) var selections: [TokenSelection] = []

    public init(tokens: [TokenScript.Token],
                contractAddress: AlphaWallet.Address,
                hasAssetDefinition: Bool) {

        self.tokens = tokens
        self.contractAddress = contractAddress
        self.hasAssetDefinition = hasAssetDefinition
    }

    public func token(tokenId: TokenId) -> TokenScript.Token? {
        tokens.first(where: { $0.id == tokenId })
    }

    public var tokenType: TokenType {
        return tokens[0].tokenType
    }

    public var count: Int {
        return tokens.count
    }

    public var tokenId: TokenId {
        return tokens[0].id
    }

    public var tokenIds: [TokenId] {
        return tokens.map({ $0.id })
    }

    public var indices: [UInt16] {
        return tokens.map { $0.index }
    }

    public var name: String {
        return tokens[0].name
    }

    public var symbol: String {
        return tokens[0].symbol
    }

    public var values: [AttributeId: AssetAttributeSyntaxValue] {
        return tokens[0].values
    }

    public var valuesAll: [TokenId: [AttributeId: AssetAttributeSyntaxValue]] {
        var valuesAll: [TokenId: [AttributeId: AssetAttributeSyntaxValue]] = [:]
        for each in tokens {
            valuesAll[each.id] = each.values
        }

        return valuesAll
    }

    public var openSeaNonFungibleTraits: [OpenSeaNonFungibleTrait]? {
        return values.traitsValue
    }

    public var status: TokenScript.Token.Status {
        return tokens[0].status
    }

    public var isSpawnableMeetupContract: Bool {
        return tokens[0].isSpawnableMeetupContract
    }

    public var type: TokenHolderType {
        if tokens.count == 1 {
            return .single
        } else {
            return .collectible
        }
    }

    public func tokenType(tokenId: TokenId) -> TokenType? {
        token(tokenId: tokenId)
            .flatMap { $0.tokenType }
    }

    public func name(tokenId: TokenId) -> String? {
        token(tokenId: tokenId)
            .flatMap { $0.name }
    }

    public func symbol(tokenId: TokenId) -> String? {
        token(tokenId: tokenId)
            .flatMap { $0.symbol }
    }

    public func values(tokenId: TokenId) -> [AttributeId: AssetAttributeSyntaxValue]? {
        token(tokenId: tokenId)
            .flatMap { $0.values }
    }

    public func status(tokenId: TokenId) -> TokenScript.Token.Status? {
        token(tokenId: tokenId)
            .flatMap { $0.status }
    }

    public func isSpawnableMeetupContract(tokenId: TokenId) -> Bool? {
        token(tokenId: tokenId)
            .flatMap { $0.isSpawnableMeetupContract }
    }

    public func openSeaNonFungibleTraits(tokenId: TokenId) -> [OpenSeaNonFungibleTrait]? {
        return token(tokenId: tokenId)?.values.traitsValue
    }

    public func assetImageUrl(tokenId: TokenId, rewriteGoogleContentSizeUrl size: GoogleContentSize = .s750) -> WebImageURL? {
        token(tokenId: tokenId)
            .flatMap { ($0.values.animationUrlUrlValue ?? $0.values.imageUrlUrlValue ?? $0.values.thumbnailUrlUrlValue ?? $0.values.contractImageUrlUrlValue) }
            .flatMap { WebImageURL(url: $0, rewriteGoogleContentSizeUrl: size) }
    }
}
