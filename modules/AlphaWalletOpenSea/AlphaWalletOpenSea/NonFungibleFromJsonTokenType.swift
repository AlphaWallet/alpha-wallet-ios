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

    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "erc721":
            self = .erc721
        case "erc1155":
            self = .erc1155
        default:
            return nil
        }
    }
}
