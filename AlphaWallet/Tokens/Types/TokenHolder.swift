//
//  TokenHolder.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/25/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation

class TokenHolder {
    enum Status {
        case available, sold, redeemed, forSale, transferred
    }

    var tokens: [Token]
    var name: String { return tokens[0].name }
    var values: [String: AssetAttributeValue] { return tokens[0].values }
    var status: Status
    var isSelected = false
    var areDetailsVisible = false
    var contractAddress: String
    var hasAssetDefinition: Bool

    init(tokens: [Token], status: Status, contractAddress: String, hasAssetDefinition: Bool) {
        self.tokens = tokens
        self.status = status
        self.contractAddress = contractAddress
        self.hasAssetDefinition = hasAssetDefinition
    }

    var count: Int {
        return tokens.count
    }

    var indices: [UInt16] {
        return tokens.map { $0.index }
    }
}
