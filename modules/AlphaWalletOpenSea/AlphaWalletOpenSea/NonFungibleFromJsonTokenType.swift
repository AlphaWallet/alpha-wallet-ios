//
//  NonFungibleFromJsonTokenType.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/30/22.
//

import Foundation

public enum NonFungibleFromJsonTokenType: String, Codable {
    case erc721
    case erc1155

    init?(rawString: String) {
        if let value = Self(rawValue: rawString.lowercased()) {
            self = value
        } else {
            return nil
        }
    }
}