// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

///Use this enum to "mark" where we handle non-fungible tokens backed by OpenSea differently instead of accessing the contract directly.
///If there is a TokenScript file available for the contract, it is assumed to be no longer "backed" by OpenSea
///If there are other special casing for tokens that doesn't fit this model, create another enum type (not case)
enum OpenSeaBackedNonFungibleTokenHandling {
    case backedByOpenSea
    case notBackedByOpenSea

    init(token: TokenObject, assetDefinitionStore: AssetDefinitionStore) {
        self = {
            if !token.balance.isEmpty && token.balance[0].balance.hasPrefix("{") && !XMLHandler(contract: token.contractAddress, assetDefinitionStore: AssetDefinitionStore()).hasAssetDefinition {
                return .backedByOpenSea
            } else {
                return .notBackedByOpenSea
            }
        }()
    }
}

///Use this enum to "mark" where we handle non-fungible tokens supported by OpenSea differently instead of accessing the contract directly
///Even if there is a TokenScript file available for the contract, it is assumed to still be supported by OpenSea
///If there are other special casing for tokens that doesn't fit this model, create another enum type (not case)
enum OpenSeaSupportedNonFungibleTokenHandling {
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
