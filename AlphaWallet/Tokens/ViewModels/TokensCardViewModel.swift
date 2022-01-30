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
import BigInt

struct TokensCardViewModel {

    var fungibleBalance: BigInt? {
        return nil
    }

    var initiallySelectedTabIndex: Int {
        return 1
    }

    private let assetDefinitionStore: AssetDefinitionStore
    let token: TokenObject
    var tokenHolders: [TokenHolder]

    var actions: [TokenInstanceAction] {
        //NOTE: Show actions only in case when there is only one token id in list, othervise user is able to select each toke to perform an action
        guard numberOfItems() == 1 else { return [] }

        let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
        let actionsFromTokenScript = xmlHandler.actions
        if actionsFromTokenScript.isEmpty {
            switch token.type {
            case .erc875, .erc721ForTickets:
                return [
                    .init(type: .nftSell),
                    .init(type: .nonFungibleTransfer)
                ]
            case .erc721, .erc1155:
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

    func item(for indexPath: IndexPath) -> TokenHolder {
        return tokenHolders[indexPath.section]
    }

    func markHolderSelected() {
        //NOTE: Toggle only in case when there is only one tokenHolder
        guard let token = tokenHolders.first, tokenHolders.count == 1 else { return }
        token.isSelected = true
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var navigationTitle: String {
        return token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
    }
    private let eventsDataStore: EventsDataStoreProtocol
    private let account: Wallet

    init(token: TokenObject, forWallet account: Wallet, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: EventsDataStoreProtocol) {
        self.token = token
        self.account = account
        self.eventsDataStore = eventsDataStore
        self.tokenHolders = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore).getTokenHolders(forWallet: account)
        self.assetDefinitionStore = assetDefinitionStore
    }

    mutating func invalidateTokenHolders() {
        tokenHolders = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)
            .getTokenHolders(forWallet: account)
    }

    func tokenHolder(at indexPath: IndexPath) -> TokenHolder {
        return tokenHolders[indexPath.section]
    }

    func numberOfItems() -> Int {
        return tokenHolders.count
    }

}
