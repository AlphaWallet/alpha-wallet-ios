//
//  NFTAssetsPageViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.08.2021.
//

import UIKit
import Combine
import AlphaWalletFoundation

struct NFTAssetsPageViewModelInput {
    let appear: AnyPublisher<Void, Never>
}

struct NFTAssetsPageViewModelOutput {
    let selection: AnyPublisher<GridOrListSelectionState, Never>
    let viewState: AnyPublisher<NFTAssetsPageViewModel.ViewState, Never>
}

final class NFTAssetsPageViewModel {

    enum AssetsSection: Int, Hashable, CaseIterable {
        case assets
    }
    
    var navigationTitle: String {
        return R.string.localizable.semifungiblesAssetsTitle()
    }

    var backgroundColor: UIColor {
        Colors.appBackground
    }

    private let selectionSubject: CurrentValueSubject<GridOrListSelectionState, Never>
    var selection: GridOrListSelectionState { selectionSubject.value }
    private let token: Token
    private let assetDefinitionStore: AssetDefinitionStore
    private let searchFilterSubject = CurrentValueSubject<ActivityOrTransactionFilter, Never>(.keyword(nil))

    var spacingForGridLayout: CGFloat {
        switch token.type {
        case .erc875, .erc721ForTickets:
            switch OpenSeaBackedNonFungibleTokenHandling(token: token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified) {
            case .notBackedByOpenSea:
                return 0
            case .backedByOpenSea:
                return 16
            }
        case .nativeCryptocurrency, .erc20, .erc721, .erc1155:
            return 16
        }
    }

    var columsForGridLayout: Int {
        switch token.type {
        case .erc875, .erc721ForTickets:
            switch OpenSeaBackedNonFungibleTokenHandling(token: token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified) {
            case .notBackedByOpenSea:
                return 1
            case .backedByOpenSea:
                return 2
            }
        case .nativeCryptocurrency, .erc20, .erc721, .erc1155:
            return 2
        }
    }

    //NOTE: height dimension calculates including additional insets applied to grid layout, pay attention on it
    var heightDimensionForGridLayout: CGFloat {
        switch token.type {
        case .erc875, .erc721ForTickets:
            switch OpenSeaBackedNonFungibleTokenHandling(token: token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified) {
            case .notBackedByOpenSea:
                return 200
            case .backedByOpenSea:
                return 261
            }
        case .nativeCryptocurrency, .erc20, .erc721, .erc1155:
            return 261
        }
    }

    var contentInsetsForGridLayout: NSDirectionalEdgeInsets {
        switch token.type {
        case .erc875, .erc721ForTickets:
            switch OpenSeaBackedNonFungibleTokenHandling(token: token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified) {
            case .notBackedByOpenSea:
                return .init(top: 0, leading: 10, bottom: 0, trailing: 10)
            case .backedByOpenSea:
                return .init(top: 16, leading: 16, bottom: 0, trailing: 16)
            }
        case .nativeCryptocurrency, .erc20, .erc721, .erc1155:
            return .init(top: 16, leading: 16, bottom: 0, trailing: 16)
        }
    }

    private let tokenHolders: AnyPublisher<[TokenHolder], Never>

    init(token: Token, assetDefinitionStore: AssetDefinitionStore, tokenHolders: AnyPublisher<[TokenHolder], Never>, selection: GridOrListSelectionState) {
        self.tokenHolders = tokenHolders
        self.selectionSubject = .init(selection)
        self.assetDefinitionStore = assetDefinitionStore
        self.token = token
    }

    func set(selection: GridOrListSelectionState) {
        selectionSubject.send(selection)
    }

    func set(searchFilter: ActivityOrTransactionFilter) {
        searchFilterSubject.send(searchFilter)
    }

    func transform(input: NFTAssetsPageViewModelInput) -> NFTAssetsPageViewModelOutput {
        let filterWhenAppear = input.appear.map { [searchFilterSubject] _ in searchFilterSubject.value }

        let sections = Publishers.CombineLatest(tokenHolders, filterWhenAppear.merge(with: searchFilterSubject))
            .compactMap { [weak self] tokenHolders, filter in self?.filter(filter, tokenHolders: tokenHolders) }
            .map { [SectionViewModel(section: .assets, views: $0)] }

        let viewState = sections
            .map { sections in NFTAssetsPageViewModel.ViewState(animatingDifferences: true, sections: sections) }
            .eraseToAnyPublisher()

        let selection = selectionSubject.removeDuplicates().eraseToAnyPublisher()

        return .init(selection: selection, viewState: viewState)
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

    private func filter(_ filter: ActivityOrTransactionFilter, tokenHolders: [TokenHolder]) -> [TokenHolder] {
        var newTokenHolders = tokenHolders

        switch filter {
        case .keyword(let keyword):
            if let valueToSearch = keyword?.trimmed.lowercased(), valueToSearch.nonEmpty {
                newTokenHolders = tokenHolders.filter { tokenHolder in
                    return self.title(for: tokenHolder).lowercased().contains(valueToSearch)
                }
            }
        }

        return newTokenHolders
    }
}

extension NFTAssetsPageViewModel {
    struct ViewState {
        let animatingDifferences: Bool
        let sections: [SectionViewModel]
    }

    struct SectionViewModel {
        let section: NFTAssetsPageViewModel.AssetsSection
        let views: [TokenHolder]
    }
}
