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
        count = json["trait_count"].intValue
        type = json["trait_type"].stringValue
        value = json["value"].stringValue
    }
}