//
//  OpenSeaNonFungibleTrait.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/30/22.
//

import Foundation
import SwiftyJSON

public struct OpenSeaNonFungibleTrait: Codable {
    public let count: Int
    public let type: String
    public let value: String

    init(json: JSON) {
        let count = json["trait_count"].intValue
        let type = json["trait_type"].stringValue
        let value = json["value"].stringValue
        self.init(count: count, type: type, value: value)
    }

    public init(count: Int, type: String, value: String) {
        self.count = count
        self.type = type
        self.value = value
    }
}