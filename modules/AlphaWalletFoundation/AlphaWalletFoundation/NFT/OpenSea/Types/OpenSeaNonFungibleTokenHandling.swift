// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletTokenScript

public enum TokenView {
    case view
    case viewIconified
}

///Use this enum to "mark" where we handle non-fungible tokens backed by OpenSea differently instead of accessing the contract directly.
///If there is a TokenScript file available for the contract, it is assumed to be no longer "backed" by OpenSea
///If there are other special casing for tokens that doesn't fit this model, create another enum type (not case)
public enum OpenSeaBackedNonFungibleTokenHandling {
    case backedByOpenSea
    case notBackedByOpenSea

    public init(token: TokenScriptSupportable, assetDefinitionStore: AssetDefinitionStore, tokenViewType: TokenView) {
        self = {
            if !token.balanceNft.isEmpty && token.balanceNft[0].balance.hasPrefix("{") {
                let xmlHandler = XMLHandler(contract: token.contractAddress, tokenType: token.type, assetDefinitionStore: assetDefinitionStore)
                let view: String
                switch tokenViewType {
                case .viewIconified:
                    view = xmlHandler.tokenViewIconifiedHtml.html
                case .view:
                    view = xmlHandler.tokenViewHtml.html
                }
                if xmlHandler.hasAssetDefinition && !view.isEmpty {
                    return .notBackedByOpenSea
                } else {
                    return .backedByOpenSea
                }
            } else {
                return .notBackedByOpenSea
            }
        }()
    }
}

///Use this enum to "mark" where we handle non-fungible tokens supported by JSON (either via OpenSea or with ERC721's `tokenURI`)
///Even if there is a TokenScript file available for the contract, it is assumed to still be supported by this way
///If there are other special casing for tokens that doesn't fit this model, create another enum type (not case)
public enum NonFungibleFromJsonSupportedTokenHandling {
    case supported
    case notSupported

    public init(token: TokenScriptSupportable) {
        self = {
            if !token.balanceNft.isEmpty && token.balanceNft[0].balance.hasPrefix("{") {
                return .supported
            } else {
                return .notSupported
            }
        }()
    }
}
