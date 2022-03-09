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

    func item(for indexPath: IndexPath) -> TokenHolder {
        return tokenHolders[indexPath.section]
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var navigationTitle: String {
        return token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
    }

    private let eventsDataStore: NonActivityEventsDataStore
    private let account: Wallet

    init(token: TokenObject, forWallet account: Wallet, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: NonActivityEventsDataStore) {
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
