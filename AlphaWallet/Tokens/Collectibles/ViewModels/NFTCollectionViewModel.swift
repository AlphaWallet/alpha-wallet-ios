//
//  NFTCollectionViewModel.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/24/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import BigInt

struct NFTCollectionViewModel {
    private(set) var tokenHolders: [TokenHolder]
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: NonActivityEventsDataStore

    let token: TokenObject
    var initiallySelectedTabIndex: Int = 1
    var backgroundColor: UIColor = Colors.appBackground

    var navigationTitle: String {
        if let name = token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: wallet) {
            return name
        } else {
            return token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
        }
    }

    var openInUrl: URL? {
        let values = tokenHolders[0].values
        return values.collectionValue.flatMap { collection -> URL? in
            guard collection.slug.trimmed.nonEmpty else { return nil }
            return URL(string: "https://opensea.io/collection/\(collection.slug)")
        }
    }

    let wallet: Wallet

    init(token: TokenObject, forWallet wallet: Wallet, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: NonActivityEventsDataStore) {
        self.token = token
        self.wallet = wallet
        self.eventsDataStore = eventsDataStore
        self.tokenHolders = token.getTokenHolders(assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: wallet)
        self.assetDefinitionStore = assetDefinitionStore
    } 

    mutating func invalidateTokenHolders() {
        tokenHolders = token.getTokenHolders(assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: wallet)
    }
}
