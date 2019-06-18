// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct TokenInstanceViewModel {
    let token: TokenObject
    let tokenHolder: TokenHolder
    let assetDefinitionStore: AssetDefinitionStore

    var actions: [TokenInstanceAction] {
        let xmlHandler = XMLHandler(contract: token.contractAddress, assetDefinitionStore: assetDefinitionStore)
        let actionsFromTokenScript = xmlHandler.actions
        if xmlHandler.hasAssetDefinition {
            return actionsFromTokenScript
        } else {
            switch token.type {
            case .erc875:
                return [
                    .init(type: .erc875Redeem),
                    .init(type: .erc875Sell),
                    .init(type: .nonFungibleTransfer)
                ]
            case .erc721:
                return [
                    .init(type: .nonFungibleTransfer)
                ]
            case .nativeCryptocurrency, .erc20:
                return []
            }
        }
    }

    func toggleSelection(for indexPath: IndexPath) {
        if tokenHolder.areDetailsVisible {
            tokenHolder.areDetailsVisible = false
            tokenHolder.isSelected = false
        } else {
            tokenHolder.areDetailsVisible = true
            tokenHolder.isSelected = true
        }
    }
}
