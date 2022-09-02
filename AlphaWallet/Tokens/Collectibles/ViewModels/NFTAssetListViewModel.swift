//
//  NFTAssetListViewControllerViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.05.2022.
//

import UIKit
import AlphaWalletFoundation

class NFTAssetListViewModel {
    let tokenHolder: TokenHolder
    private var filteredTokenHolders: [TokenHolderWithItsTokenIds] = []

    var headerBackgroundColor: UIColor = Colors.appWhite

    var navigationTitle: String {
        return tokenHolder.name
    }

    var backgroundColor: UIColor = GroupedTable.Color.background

    var isSearchActive: Bool = false

    var numberOfSections: Int {
        filteredTokenHolders.count
    }

    func numberOfTokens(section: Int) -> Int {
        return filteredTokenHolders[section].tokensIds.count
    }

    func titleForTokenHolder(section: Int) -> String {
        return filteredTokenHolders[section].tokenHolder.name
    }

    func tokenHolderSelection(indexPath: IndexPath) -> TokenHolderSelection {
        let pair = filteredTokenHolders[indexPath.section]

        return (pair.tokensIds[indexPath.row], pair.tokenHolder)
    }

    func selectableTokenHolder(at section: Int) -> TokenHolder {
        return filteredTokenHolders[section].tokenHolder
    }

    init(tokenHolder: TokenHolder) {
        self.tokenHolder = tokenHolder

        filteredTokenHolders = [
            .init(tokenHolder: tokenHolder, tokensIds: tokenHolder.tokenIds)
        ]
    }
}
