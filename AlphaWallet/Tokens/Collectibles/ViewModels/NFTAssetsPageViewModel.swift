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
    let willAppear: AnyPublisher<Void, Never>
}

struct NFTAssetsPageViewModelOutput {
    let layout: AnyPublisher<GridOrListLayout, Never>
    let viewState: AnyPublisher<NFTAssetsPageViewModel.ViewState, Never>
}

final class NFTAssetsPageViewModel {
    private let layoutSubject: CurrentValueSubject<GridOrListLayout, Never>
    private let token: Token
    private let assetDefinitionStore: AssetDefinitionStore
    private let searchFilterSubject = CurrentValueSubject<ActivityOrTransactionFilter, Never>(.keyword(nil))
    private let tokenHolders: AnyPublisher<[TokenHolder], Never>

    var layout: GridOrListLayout { layoutSubject.value }
    var title: String { R.string.localizable.semifungiblesAssetsTitle() }

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

    init(token: Token,
         assetDefinitionStore: AssetDefinitionStore,
         tokenHolders: AnyPublisher<[TokenHolder], Never>,
         layout: GridOrListLayout) {

        self.tokenHolders = tokenHolders
        self.layoutSubject = .init(layout)
        self.assetDefinitionStore = assetDefinitionStore
        self.token = token
    }

    func set(layout: GridOrListLayout) {
        layoutSubject.send(layout)
    }

    func set(searchFilter: ActivityOrTransactionFilter) {
        searchFilterSubject.send(searchFilter)
    }

    func transform(input: NFTAssetsPageViewModelInput) -> NFTAssetsPageViewModelOutput {
        let filterWhenAppear = input.willAppear
            .map { [searchFilterSubject] _ in searchFilterSubject.value }

        let filter = Publishers.Merge(searchFilterSubject, filterWhenAppear)

        let assets = Publishers.CombineLatest(tokenHolders, filter)
            .map { functional.filter($1, tokenHolders: $0) }
            .map { $0.sorted { $0.tokenId < $1.tokenId } }
            .map { [SectionViewModel(section: .assets, views: $0)] }

        let viewState = assets
            .map { functional.buildSnapshot(for: $0) }
            .map { NFTAssetsPageViewModel.ViewState(animatingDifferences: true, snapshot: $0) }
            .eraseToAnyPublisher()

        let layout = layoutSubject.removeDuplicates().eraseToAnyPublisher()

        return .init(layout: layout, viewState: viewState)
    }
}

extension NFTAssetsPageViewModel {
    enum functional {}
}

fileprivate extension NFTAssetsPageViewModel.functional {
    static func buildSnapshot(for viewModels: [NFTAssetsPageViewModel.SectionViewModel]) -> NFTAssetsPageViewModel.Snapshot {
        var snapshot = NSDiffableDataSourceSnapshot<NFTAssetsPageViewModel.Section, TokenHolder>()
        let sections = viewModels.map { $0.section }
        snapshot.appendSections(sections)
        for each in viewModels {
            snapshot.appendItems(each.views, toSection: each.section)
        }
        return snapshot
    }

    static func nftAssetTitleForFiltering(for tokenHolder: TokenHolder) -> String {
        let displayHelper = OpenSeaNonFungibleTokenDisplayHelper(contract: tokenHolder.contractAddress)
        let tokenId = tokenHolder.values.tokenIdStringValue ?? ""
        if let name = tokenHolder.values.nameStringValue.nilIfEmpty {
            return displayHelper.title(fromTokenName: name, tokenId: tokenId)
        } else {
            return displayHelper.title(fromTokenName: tokenHolder.name, tokenId: tokenId)
        }
    }

    static func filter(_ filter: ActivityOrTransactionFilter, tokenHolders: [TokenHolder]) -> [TokenHolder] {
        var newTokenHolders = tokenHolders

        switch filter {
        case .keyword(let keyword):
            if let valueToSearch = keyword?.trimmed.lowercased(), valueToSearch.nonEmpty {
                newTokenHolders = tokenHolders.filter { tokenHolder in
                    return nftAssetTitleForFiltering(for: tokenHolder).lowercased().contains(valueToSearch)
                }
            }
        }

        return newTokenHolders
    }
}

extension NFTAssetsPageViewModel {
    typealias Snapshot = NSDiffableDataSourceSnapshot<NFTAssetsPageViewModel.Section, TokenHolder>

    struct ViewState {
        let animatingDifferences: Bool
        let snapshot: NFTAssetsPageViewModel.Snapshot
    }

    struct SectionViewModel {
        let section: NFTAssetsPageViewModel.Section
        let views: [TokenHolder]
    }

    enum Section: Int, Hashable, CaseIterable {
        case assets
    }
}
