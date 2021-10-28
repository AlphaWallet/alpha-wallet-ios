//
//  TokensCardCollectionViewControllerViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.11.2021.
//

import UIKit
import BigInt

struct TokensCardCollectionViewControllerViewModel {

    var fungibleBalance: BigInt? {
        return nil
    }

    private let assetDefinitionStore: AssetDefinitionStore
    let token: TokenObject
    let tokenHolders: [TokenHolder]
    let actions: [TokenInstanceAction] = []

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var navigationTitle: String {
        return token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
    }

    init(token: TokenObject, forWallet account: Wallet, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: EventsDataStoreProtocol) {
        self.token = token
        self.tokenHolders = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore).getTokenHolders(forWallet: account)
        self.assetDefinitionStore = assetDefinitionStore
    }

    func tokenHolder(at indexPath: IndexPath) -> TokenHolder {
        return tokenHolders[indexPath.section]
    }

    func numberOfItems() -> Int {
        return tokenHolders.count
    }

}
