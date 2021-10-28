//
//  TokenHolder.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/25/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import BigInt

struct TokenSelection: Equatable {
    let tokenId: TokenId
    let value: Int

    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.tokenId == rhs.tokenId
    }
}

enum TokenHolderSelectionStrategy {
    case all
    case token(tokenId: TokenId, amount: Int)
    case allFor(tokenId: TokenId)
}

enum TokenHolderUnselectionStrategy {
    case all
    case token(token: TokenId)
}

extension TokenHolder {

    func isSelected(tokenId: TokenId) -> Bool {
        selections.contains { $0.tokenId == tokenId }
    }

    var totalSelectedCount: Int {
        var sum: Int = 0
        for each in selections {
            sum += each.value
        }

        return sum
    }

    func selectedCount(tokenId: TokenId) -> Int? {
        selections.first(where: { $0.tokenId == tokenId }).flatMap { $0.value }
    }

    func select(with strategy: TokenHolderSelectionStrategy) {
        switch strategy {
        case .allFor(let tokenId):
            guard let token = token(tokenId: tokenId) else { return }
            select(with: .token(tokenId: tokenId, amount: token.value ?? 0))
        case .all:
            selections = tokens.compactMap {
                //TODO need to make sure the available `amount` is set previously  so we can use it here
                if let value = $0.value {
                    return TokenSelection(tokenId: $0.id, value: value)
                } else {
                    return nil
                }
            }
        case .token(let tokenId, let newAmount):
            guard tokens.contains(where: { $0.id == tokenId }) else { return }
            if let index = selections.firstIndex(where: { $0.tokenId == tokenId }) {
                if newAmount > 0 {
                    selections[index] = TokenSelection(tokenId: tokenId, value: newAmount)
                } else {
                    selections.remove(at: index)
                }
            } else {
                guard newAmount > 0 else { return }
                selections.append(TokenSelection(tokenId: tokenId, value: newAmount))
            }
        }
    }

    func unselect(with strategy: TokenHolderSelectionStrategy) {
        switch strategy {
        case .all:
            selections = []
        case .allFor(let tokenId):
            guard let token = token(tokenId: tokenId) else { return }
            unselect(with: .token(tokenId: tokenId, amount: token.value ?? 0))
        case .token(let tokenId, let amount):
            if let index = selections.firstIndex(where: { $0.tokenId == tokenId }) {
                selections[index] = TokenSelection(tokenId: tokenId, value: amount)
            } else {
                // no-op
            }
        }
    }
}

enum TokenHolderType {
    case collectible
    case single
}

class TokenHolder {
    let tokens: [Token]
    let contractAddress: AlphaWallet.Address
    let hasAssetDefinition: Bool

    var isSelected = false
    var areDetailsVisible = false
    var selections: [TokenSelection] = []

    init(tokens: [Token], contractAddress: AlphaWallet.Address, hasAssetDefinition: Bool) {
        self.tokens = tokens
        self.contractAddress = contractAddress
        self.hasAssetDefinition = hasAssetDefinition
    }

    func token(tokenId: TokenId) -> Token? {
        tokens.first(where: { $0.id == tokenId })
    }

    var tokenType: TokenType {
        return tokens[0].tokenType
    }

    var count: Int {
        return tokens.count
    }

    var tokenId: TokenId {
        return tokens[0].id
    }

    var tokenIds: [TokenId] {
        return tokens.map({ $0.id })
    }

    var indices: [UInt16] {
        return tokens.map { $0.index }
    }

    var name: String {
        return tokens[0].name
    }

    var symbol: String {
        return tokens[0].symbol
    }

    var values: [AttributeId: AssetAttributeSyntaxValue] {
        return tokens[0].values
    }

    var valuesAll: [TokenId: [AttributeId: AssetAttributeSyntaxValue]] {
        var valuesAll: [TokenId: [AttributeId: AssetAttributeSyntaxValue]] = [:]
        for each in tokens {
            valuesAll[each.id] = each.values
        }

        return valuesAll
    }

    var openSeaNonFungibleTraits: [OpenSeaNonFungibleTrait]? {
        guard let traitsValue = values.traitsAssetInternalValueValue else { return nil }
        switch traitsValue {
        case .openSeaNonFungibleTraits(let traits):
            return traits
        case .address, .string, .int, .uint, .generalisedTime, .bool, .subscribable, .bytes:
            return nil
        }
    }

    var status: Token.Status {
        return tokens[0].status
    }

    var isSpawnableMeetupContract: Bool {
        return tokens[0].isSpawnableMeetupContract
    }

    var type: TokenHolderType {
        if tokens.count == 1 {
            return .single
        } else {
            return .collectible
        }
    }

    func tokenType(tokenId: TokenId) -> TokenType? {
        token(tokenId: tokenId).flatMap { $0.tokenType }
    }

    func name(tokenId: TokenId) -> String? {
        token(tokenId: tokenId).flatMap { $0.name }
    }

    func symbol(tokenId: TokenId) -> String? {
        token(tokenId: tokenId).flatMap { $0.symbol }
    }

    func values(tokenId: TokenId) -> [AttributeId: AssetAttributeSyntaxValue]? {
        token(tokenId: tokenId).flatMap { $0.values }
    }

    func status(tokenId: TokenId) -> Token.Status? {
        token(tokenId: tokenId).flatMap { $0.status }
    }

    func isSpawnableMeetupContract(tokenId: TokenId) -> Bool? {
        token(tokenId: tokenId).flatMap { $0.isSpawnableMeetupContract }
    }

    func openSeaNonFungibleTraits(tokenId: TokenId) -> [OpenSeaNonFungibleTrait]? {
        switch token(tokenId: tokenId).flatMap({ $0.values.traitsAssetInternalValueValue }) {
        case .openSeaNonFungibleTraits(let traits):
            return traits
        case .address, .string, .int, .uint, .generalisedTime, .bool, .subscribable, .bytes, .none:
            return nil
        }
    }
}
