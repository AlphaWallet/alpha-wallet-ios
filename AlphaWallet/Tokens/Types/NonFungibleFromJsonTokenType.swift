// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

enum NonFungibleFromJsonTokenType: String, Codable {
    case erc721
    case erc1155

    init?(rawString: String) {
        if let value = Self(rawValue: rawString.lowercased()) {
            self = value
        } else {
            return nil
        }
    } 

    var asTokenType: TokenType {
        switch self {
        case .erc721:
            return .erc721
        case .erc1155:
            return .erc1155
        }
    }
}
