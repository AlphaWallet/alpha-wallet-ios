//
//  TokenHolder.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/25/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation

class TokenHolder {
    let tokens: [Token]
    let contractAddress: AlphaWallet.Address
    let hasAssetDefinition: Bool

    var isSelected = false
    var areDetailsVisible = false

    init(tokens: [Token], contractAddress: AlphaWallet.Address, hasAssetDefinition: Bool) {
        self.tokens = tokens
        self.contractAddress = contractAddress
        self.hasAssetDefinition = hasAssetDefinition
    }

    var count: Int {
        return tokens.count
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
        case .address, .string, .int, .uint, .generalisedTime, .bool, .subscribable:
            return nil
        }
    }

    var status: Token.Status {
        return tokens[0].status
    }

    var isSpawnableMeetupContract: Bool {
        return tokens[0].isSpawnableMeetupContract
    }
}
