//
//  TokensCardViewModel.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/24/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit
import PromiseKit

struct TokensCardViewModel {
    private let assetDefinitionStore: AssetDefinitionStore

    let token: TokenObject
    let tokenHolders: [TokenHolder]

    var actions: [TokenInstanceAction] {
        let xmlHandler = XMLHandler(contract: token.contractAddress, assetDefinitionStore: assetDefinitionStore)
        let actionsFromTokenScript = xmlHandler.actions
        if actionsFromTokenScript.isEmpty {
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
        } else {
            return actionsFromTokenScript
        }
    }

    var tokenScriptStatus: Promise<TokenLevelTokenScriptDisplayStatus> {
        let xmlHandler = XMLHandler(contract: token.contractAddress, assetDefinitionStore: assetDefinitionStore)
        return xmlHandler.tokenScriptStatus
    }

    init(token: TokenObject, forWallet account: Wallet, assetDefinitionStore: AssetDefinitionStore) {
        self.token = token
        self.tokenHolders = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore).getTokenHolders(forWallet: account)
        self.assetDefinitionStore = assetDefinitionStore
    }

    func item(for indexPath: IndexPath) -> TokenHolder {
        return tokenHolders[indexPath.row]
    }

    func numberOfItems(for section: Int) -> Int {
        return tokenHolders.count
    }

    func toggleDetailsVisible(for indexPath: IndexPath) -> [IndexPath] {
        let tokenHolder = item(for: indexPath)
        var changed = [indexPath]
        if tokenHolder.areDetailsVisible {
            tokenHolder.areDetailsVisible = false
        } else {
            for (i, each) in tokenHolders.enumerated() where each.areDetailsVisible {
                each.areDetailsVisible = false
                changed.append(.init(row: i, section: indexPath.section))
            }
            tokenHolder.areDetailsVisible = true
        }
        return changed
    }

    func toggleSelection(for indexPath: IndexPath) -> [IndexPath] {
        let tokenHolder = item(for: indexPath)
        var changed = [indexPath]
        if tokenHolder.areDetailsVisible {
            tokenHolder.areDetailsVisible = false
            tokenHolder.isSelected = false
        } else {
            for (i, each) in tokenHolders.enumerated() where each.areDetailsVisible {
                each.areDetailsVisible = false
                each.isSelected = false
                changed.append(.init(row: i, section: indexPath.section))
            }
            tokenHolder.areDetailsVisible = true
            tokenHolder.isSelected = true
        }
        return changed
    }
}
