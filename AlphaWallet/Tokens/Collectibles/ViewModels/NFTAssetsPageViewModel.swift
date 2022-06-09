//
//  NFTAssetsPageViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.08.2021.
//

import UIKit

class NFTAssetsPageViewModel {

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
    private let token: TokenObject
    private let assetDefinitionStore: AssetDefinitionStore

    var searchFilter: ActivityOrTransactionFilter = .keyword(nil) {
        didSet {
            filter(searchFilter, tokenHolders: tokenHolders)
        }
    }

    var spacingForGridLayout: CGFloat {
        switch token.type {
        case .erc875:
            switch OpenSeaBackedNonFungibleTokenHandling(token: token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified) {
            case .notBackedByOpenSea:
                return 0
            case .backedByOpenSea:
                return 16
            }
        case .nativeCryptocurrency, .erc20, .erc721, .erc721ForTickets, .erc1155:
            return 16
        }
    }

    var columsForGridLayout: Int {
        switch token.type {
        case .erc875:
            switch OpenSeaBackedNonFungibleTokenHandling(token: token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified) {
            case .notBackedByOpenSea:
                return 1
            case .backedByOpenSea:
                return 2
            }
        case .nativeCryptocurrency, .erc20, .erc721, .erc721ForTickets, .erc1155:
            return 2
        }
    }

    //NOTE: height dimension calculates including additional insets applied to grid layout, pay attention on it
    var heightDimensionForGridLayout: CGFloat {
        switch token.type {
        case .erc875:
            switch OpenSeaBackedNonFungibleTokenHandling(token: token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified) {
            case .notBackedByOpenSea:
                return 200
            case .backedByOpenSea:
                return 261
            }
        case .nativeCryptocurrency, .erc20, .erc721, .erc721ForTickets, .erc1155:
            return 261
        }
    }

    var contentInsetsForGridLayout: NSDirectionalEdgeInsets {
        switch token.type {
        case .erc875:
            switch OpenSeaBackedNonFungibleTokenHandling(token: token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified) {
            case .notBackedByOpenSea:
                return .init(top: 0, leading: 10, bottom: 0, trailing: 10)
            case .backedByOpenSea:
                return .init(top: 16, leading: 16, bottom: 0, trailing: 16)
            }
        case .nativeCryptocurrency, .erc20, .erc721, .erc721ForTickets, .erc1155:
            return .init(top: 16, leading: 16, bottom: 0, trailing: 16)
        }
    }

    init(token: TokenObject, assetDefinitionStore: AssetDefinitionStore, tokenHolders: [TokenHolder], selection: GridOrListSelectionState) {
        self.tokenHolders = tokenHolders
        self.selection = selection
        self.assetDefinitionStore = assetDefinitionStore
        self.token = token
    }

    func tokenHolder(for indexPath: IndexPath) -> TokenHolder? {
        switch sections[safe: indexPath.section] {
        case .assets: return filteredTokenHolders[safe: indexPath.row]
        case .none: return nil
        }
    }

    private func title(for tokenHolder: TokenHolder) -> String {
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
                newTokenHolders = tokenHolders.filter { tokenHolder in
                    return self.title(for: tokenHolder).lowercased().contains(valueToSearch)
                }
            }
        }

        filteredTokenHolders = newTokenHolders
    }
}

