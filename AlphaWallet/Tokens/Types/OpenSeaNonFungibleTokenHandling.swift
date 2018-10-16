// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

///Use this enum to "mark" where we handle non-fungible tokens supported by OpenSea differently instead of accessing the contract directly
///If there are other special casing for tokens that doesn't fit this model, create another enum type (not case)
enum OpenSeaNonFungibleTokenHandling {
    case supportedByOpenSea
    case notSupportedByOpenSea

    init(token: TokenObject) {
        self = {
            if !token.balance.isEmpty && token.balance[0].balance.hasPrefix("{") {
                return .supportedByOpenSea
            } else {
                return .notSupportedByOpenSea
            }
        }()
    }
}
