//
//  NFTAssetListViewControllerViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.05.2022.
//

import UIKit
import AlphaWalletFoundation
import Combine

struct NFTAssetListViewModelInput {
    let appear: AnyPublisher<Void, Never>
}

struct NFTAssetListViewModelOutput {
    let viewState: AnyPublisher<NFTAssetListViewModel.ViewState, Never>
}

final class NFTAssetListViewModel {
    private var filteredTokenHolders: [TokenHolderWithItsTokenIds] = []
    private var containerViewState: ContainerViewState {
        return .init(backgroundColor: backgroundColor, accessoryType: .none, selectionStyle: .none)
    }

    let tokenHolder: TokenHolder
    var headerBackgroundColor: UIColor = Colors.appWhite
    var backgroundColor: UIColor = GroupedTable.Color.background

    init(tokenHolder: TokenHolder) {
        self.tokenHolder = tokenHolder
    }

    func transform(input: NFTAssetListViewModelInput) -> NFTAssetListViewModelOutput {
        let tokenHolder = input.appear
            .map { _ in return self.tokenHolder }
            .share(replay: 1)

        let snapshot = tokenHolder
            .map { [TokenHolderWithItsTokenIds(tokenHolder: $0, tokensIds: $0.tokenIds)] }
            .handleEvents(receiveOutput: { self.filteredTokenHolders = $0 })
            .map { selections in
                let views = selections.flatMap { selection in
                    selection.tokensIds.map {
                        AssetViewState(tokenHolder: selection.tokenHolder, tokenId: $0, containerViewState: self.containerViewState, layout: .list)
                    }
                }
                return NFTAssetListViewModel.SectionViewModel(section: .assets, views: views)
            }.map { self.buildSnapshot(for: [$0]) }

        let title = tokenHolder
            .map { $0.name }

        let viewState = Publishers.CombineLatest(snapshot, title)
            .map { NFTAssetListViewModel.ViewState(snapshot: $0, title: $1) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState)
    }

    func tokenHolderSelection(indexPath: IndexPath) -> TokenHolderSelection {
        let pair = filteredTokenHolders[indexPath.section]

        return (pair.tokensIds[indexPath.row], pair.tokenHolder)
    }

    private func buildSnapshot(for viewModels: [NFTAssetListViewModel.SectionViewModel]) -> NFTAssetListViewModel.Stapshot {
        var snapshot = NSDiffableDataSourceSnapshot<NFTAssetListViewModel.Section, NFTAssetListViewModel.AssetViewState>()
        let sections = viewModels.map { $0.section }
        snapshot.appendSections(sections)
        for each in viewModels {
            snapshot.appendItems(each.views, toSection: each.section)
        }
        return snapshot
    }
}

extension NFTAssetListViewModel {
    enum Section: String {
        case assets
    }

    typealias Stapshot = NSDiffableDataSourceSnapshot<NFTAssetListViewModel.Section, NFTAssetListViewModel.AssetViewState>

    struct AssetViewState: Hashable {
        let tokenHolder: TokenHolder
        let tokenId: TokenId
        let containerViewState: ContainerViewState
        let layout: GridOrListLayout
    }

    struct ContainerViewState: Hashable {
        let backgroundColor: UIColor
        let accessoryType: UITableViewCell.AccessoryType
        let selectionStyle: UITableViewCell.SelectionStyle
    }

    struct SectionViewModel {
        let section: Section
        let views: [NFTAssetListViewModel.AssetViewState]
    }

    struct ViewState {
        let snapshot: Stapshot
        let title: String
    }
}
