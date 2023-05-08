// Copyright © 2021 Stormbird PTE. LTD.

import AlphaWalletOpenSea
import Foundation

extension NonFungibleFromJsonTokenType {
    var asTokenType: TokenType {
        switch self {
        case .erc721:
            return .erc721
        case .erc1155:
            return .erc1155
        }
    }
}