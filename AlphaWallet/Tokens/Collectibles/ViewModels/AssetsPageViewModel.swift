//
//  AssetsPageViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.08.2021.
//

import UIKit

class AssetsPageViewModel {

    enum AssetsSection: Int, Hashable, CaseIterable {
        case assets
    }
    
    var navigationTitle: String {
        return R.string.localizable.semifungiblesAssetsTitle()
    }

    var backgroundColor: UIColor {
        Colors.appBackground
    }

    private let tokenHolders: [TokenHolder]
    private (set) var filteredTokenHolders: [TokenHolder] = []
    private (set) var sections: [AssetsSection] = [.assets]
    private (set) var selection: GridOrListSelectionState

    var searchFilter: ActivityOrTransactionFilter = .keyword(nil) {
        didSet {
            filter(searchFilter, tokenHolders: tokenHolders)
        }
    }

    init(tokenHolders: [TokenHolder], selection: GridOrListSelectionState) {
        self.tokenHolders = tokenHolders
        self.selection = selection
    }

    func item(atIndexPath indexPath: IndexPath) -> TokenHolder? {
        switch sections[safe: indexPath.section] {
        case .assets:
            return filteredTokenHolders[safe: indexPath.row]
        case .none:
            return nil
        }
    }

    private func titleFor(tokenHolder: TokenHolder) -> String {
        let displayHelper = OpenSeaNonFungibleTokenDisplayHelper(contract: tokenHolder.contractAddress)
        let tokenId = tokenHolder.values.tokenIdStringValue ?? ""
        if let name = tokenHolder.values.nameStringValue.nilIfEmpty {
            return name
        } else {
            return displayHelper.title(fromTokenName: tokenHolder.name, tokenId: tokenId)
        }
    }

    private func filter(_ filter: ActivityOrTransactionFilter, tokenHolders: [TokenHolder]) {
        var newTokenHolders = tokenHolders

        switch filter {
        case .keyword(let keyword):
            if let valueToSearch = keyword?.trimmed.lowercased(), valueToSearch.nonEmpty {
                newTokenHolders = tokenHolders.filter { element in
                    return self.titleFor(tokenHolder: element).lowercased().contains(valueToSearch)
                }
            }
        }

        filteredTokenHolders = newTokenHolders
    }
}

