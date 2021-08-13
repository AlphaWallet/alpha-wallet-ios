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
    var amount: Int?
    let tokenId: TokenId

    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.tokenId == rhs.tokenId
    }
}

enum TokenHolderSelectionStrategy {
    case all
    case token(tokenId: TokenId, amount: Int)
}

enum TokenHolderUnselectionStrategy {
    case all
    case token(token: TokenId)
}

extension TokenHolder {

    func isSelected(tokenId: TokenId) -> Bool {
        guard let selection = selections.first(where: { $0.tokenId == tokenId }) else { return false }

        if let amount = selection.amount {
            return amount > 0
        } else {
            return true
        }
    }

    var totalSelectedCount: Int {
        var sum: Int = 0
        for each in selections {
            if let amount = each.amount {
                sum += amount
            } else {
                sum += 1
            }
        }

        return sum
    }

    func selectedCount(tokenId: TokenId) -> Int? {
        selections.first(where: { $0.tokenId == tokenId }).flatMap { $0.amount }
    }

    func select(with strategy: TokenHolderSelectionStrategy) {
        switch strategy {
        case .all:
            selections = tokens.map { TokenSelection(amount: $0.amount, tokenId: $0.id) }
        case .token(let tokenId, let newAmount):
            guard let token = tokens.first(where: { $0.id == tokenId }) else { return }

            if let index = selections.firstIndex(where: { $0.tokenId == tokenId }) {
                if newAmount > 0 {
                    let selection: TokenSelection
                    if let available = token.amount {
                        selection = TokenSelection(amount: min(available, newAmount), tokenId: tokenId)
                    } else {
                        selection = TokenSelection(amount: nil, tokenId: tokenId)
                    }
                    selections[index] = selection
                } else {
                    selections.remove(at: index)
                }
            } else {
                guard newAmount > 0 else { return }

                if let available = token.amount {
                    selections += [TokenSelection(amount: min(available, newAmount), tokenId: tokenId)]
                } else {
                    selections += [TokenSelection(amount: nil, tokenId: tokenId)]
                }
            }
        }
    }

    func unselect(with strategy: TokenHolderSelectionStrategy) {
        switch strategy {
        case .all:
            selections = []
        case .token(let tokenId, let amount):
            if let index = selections.firstIndex(where: { $0.tokenId == tokenId }) {
                if let availableAmount = selections[index].amount {
                    let newAmount = max(0, availableAmount - amount)
                    selections[index] = TokenSelection(amount: newAmount, tokenId: tokenId)
                } else {
                    selections.remove(at: index)
                }
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

    fileprivate var selections: [TokenSelection] = []

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

    var tokenIds: [BigUInt] {
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

    var openSeaNonFungibleTraits: [OpenSeaNonFungibleTrait]? {
        guard let traitsValue = values["traits"]?.value else { return nil }
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
        switch token(tokenId: tokenId).flatMap({ $0.values["traits"]?.value }) {
        case .openSeaNonFungibleTraits(let traits):
            return traits
        case .address, .string, .int, .uint, .generalisedTime, .bool, .subscribable, .bytes, .none:
            return nil
        }
    }
}
