//
//  SelectTokenViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.07.2020.
//

import UIKit
import AlphaWalletFoundation
import Combine

typealias TokenHolderSelection = (tokenId: TokenId, tokenHolder: TokenHolder)

struct TokenHolderWithItsTokenIds {
    let tokenHolder: TokenHolder
    let tokensIds: [TokenId]

    init(tokenHolder: TokenHolder, tokensIds: [TokenId]) {
        self.tokenHolder = tokenHolder
        self.tokensIds = tokensIds
    }
}

struct NFTAssetSelectionViewModelInput {
    let assetsFilter: AnyPublisher<NFTAssetSelectionViewModel.AssetFilter, Never>
    let toolbarAction: AnyPublisher<NFTAssetSelectionViewModel.ToolbarAction, Never>
    let assetsSelection: AnyPublisher<NFTAssetSelectionViewModel.AssetsSelection, Never>
    let selectedAsset: AnyPublisher<NFTAssetSelectionViewModel.SelectedAsset, Never>
    let willAppear: AnyPublisher<Void, Never>
}

struct NFTAssetSelectionViewModelOutput {
    let viewState: AnyPublisher<NFTAssetSelectionViewModel.ViewState, Never>
    let manualAssetsAmountSelection: AnyPublisher<NFTAssetSelectionViewModel.ManualAssetsSelectionViewModel, Never>
    let sendSelected: AnyPublisher<(token: Token, tokenHolders: [TokenHolder]), Never>
}

class NFTAssetSelectionViewModel {
    private let token: Token
    private let tokenHolders: [TokenHolder]
    private var filteredTokenHolders: [TokenHolderWithItsTokenIds] = []
    private var cancellable = Set<AnyCancellable>()
    private let reloadSubject = PassthroughSubject<Void, Never>()

    func transform(input: NFTAssetSelectionViewModelInput) -> NFTAssetSelectionViewModelOutput {
        input.selectedAsset
            .sink { [weak self] in self?.handle(selectedAsset: $0) }
            .store(in: &cancellable)

        let toolbarSelection = input.toolbarAction
            .compactMap { action -> NFTAssetSelectionViewModel.AssetsSelection? in
                switch action {
                case .clear: return .unselectAll
                case .selectAll: return .allAvailable
                case .deal, .sell, .send: return nil
                }
            }

        Publishers.Merge(input.assetsSelection, toolbarSelection)
            .sink { [weak self] in self?.handle(selection: $0) }
            .store(in: &cancellable)

        let manualAssetsAmountSelection = manualAssetsSelection(input: input.assetsSelection)

        let viewState = Publishers.Merge(input.willAppear, reloadSubject)
            .flatMapLatest { _ in Publishers.Merge(input.assetsFilter, Just(AssetFilter.none)) }
            .map { NFTAssetSelectionViewModel.functional.filter(tokenHolders: self.tokenHolders, with: $0) }
            .handleEvents(receiveOutput: { self.filteredTokenHolders = $0 })
            .map { self.buildSnapshot(viewModels: $0) }
            .map { snapshot -> NFTAssetSelectionViewModel.ViewState in
                return .init(title: self.buildTitle(), actions: self.buildToolbarActions(), snapshot: snapshot)
            }

        let sendSelected = input.toolbarAction
            .filter { $0 == .send }
            .map { _ in (token: self.token, tokenHolders: self.tokenHolders) }

        return .init(
            viewState: viewState.eraseToAnyPublisher(),
            manualAssetsAmountSelection: manualAssetsAmountSelection.eraseToAnyPublisher(),
            sendSelected: sendSelected.eraseToAnyPublisher())
    }

    func selectionViewModel(indexPath: IndexPath) -> AssetSelectionViewModel {
        let pair = filteredTokenHolders[indexPath.section]
        return AssetSelectionViewModel(tokenHolder: pair.tokenHolder, tokenId: pair.tokensIds[indexPath.row])
    }

    init(token: Token, tokenHolders: [TokenHolder]) {
        self.token = token
        self.tokenHolders = tokenHolders
    }

    private func selectAssets(indexPath: IndexPath, selected: Int) {
        let pair = filteredTokenHolders[indexPath.section]
        pair.tokenHolder.select(with: .token(tokenId: pair.tokensIds[indexPath.row], amount: selected))
    }

    private func selectAllAssets(for section: Int) {
        let tokenHolder = tokenHolders[section]
        tokenHolder.select(with: .all)
    }

    private func selectAllAssets() {
        tokenHolders.forEach { $0.select(with: .all) }
    }

    private func unselectAllAssets() {
        tokenHolders.forEach { $0.unselect(with: .all) }
    }

    private var tokenSelectionCount: Int {
        var sum: Int = 0
        for tokenHolder in tokenHolders {
            sum += tokenHolder.totalSelectedCount
        }

        return sum
    }

    private func manualAssetsSelection(input: AnyPublisher<NFTAssetSelectionViewModel.AssetsSelection, Never>) -> ManualAssetsSelectionPublisher {
        input.compactMap { selection -> ManualAssetsSelectionViewModel? in
            switch selection {
            case .item(let indexPath):
                let viewModel = self.selectionViewModel(indexPath: indexPath)
                guard !viewModel.isSingleSelectionEnabled else { return nil }

                return .init(indexPath: indexPath, available: viewModel.available, selected: viewModel.selected)
            case .unselectAll, .allAvailable, .all:
                return nil
            }
        }.eraseToAnyPublisher()
    }

    private func buildSnapshot(viewModels: [TokenHolderWithItsTokenIds]) -> Snapshot {
        var snapshot = Snapshot()
        let sections = viewModels.map { $0.tokenHolder }.map { Section(name: $0.name, tokenId: $0.tokenId) }
        snapshot.appendSections(sections)
        for each in viewModels {
            let views = each.tokensIds.map { AssetSelectionViewModel(tokenHolder: each.tokenHolder, tokenId: $0) }
            snapshot.appendItems(views, toSection: Section(name: each.tokenHolder.name, tokenId: each.tokenHolder.tokenId))
        }

        return snapshot
    }

    private func handle(selectedAsset: NFTAssetSelectionViewModel.SelectedAsset) {
        selectAssets(indexPath: selectedAsset.indexPath, selected: selectedAsset.selected)
        reloadSubject.send(())
    }

    private func handle(selection: NFTAssetSelectionViewModel.AssetsSelection) {
        switch selection {
        case .item(let indexPath):
            let viewModel = selectionViewModel(indexPath: indexPath)
            guard viewModel.isSingleSelectionEnabled else { return }

            let selected = viewModel.isSelected ? 0 : 1
            selectAssets(indexPath: indexPath, selected: selected)

            reloadSubject.send(())
        case .unselectAll:
            unselectAllAssets()
            reloadSubject.send(())
        case .allAvailable:
            selectAllAssets()
            reloadSubject.send(())
        case .all(let section):
            selectAllAssets(for: section)
            reloadSubject.send(())
        }
    }

    private func buildToolbarActions() -> [ToolbarActionViewModel] {
        let actions: [NFTAssetSelectionViewModel.ToolbarAction] = [.clear, .selectAll, .send]

        return actions.map { type -> ToolbarActionViewModel in
            let isEnabled: Bool
            switch type {
            case .clear, .selectAll:
                isEnabled = true
            case .deal, .sell, .send:
                isEnabled = tokenHolders.contains(where: { $0.totalSelectedCount > 0 })
            }
            return ToolbarActionViewModel(
                type: type,
                name: type.title,
                isEnabled: isEnabled)
        }
    }

    private func buildTitle() -> String {
        if tokenSelectionCount > 0 {
            return R.string.localizable.semifungiblesSelectedTokens2(String(tokenSelectionCount))
        } else {
            return R.string.localizable.assetsSelectAssetTitle()
        }
    }
}

extension NFTAssetSelectionViewModel {
    typealias ManualAssetsSelectionPublisher = AnyPublisher<ManualAssetsSelectionViewModel, Never>
    class DataSource: UITableViewDiffableDataSource<NFTAssetSelectionViewModel.Section, AssetSelectionViewModel> {}
    typealias Snapshot = NSDiffableDataSourceSnapshot<NFTAssetSelectionViewModel.Section, AssetSelectionViewModel>

    struct ManualAssetsSelectionViewModel {
        let indexPath: IndexPath
        let available: Int
        let selected: Int
    }

    struct Section: Hashable {
        let name: String
        let tokenId: TokenId
    }

    enum AssetFilter {
        case keyword(String?)
        case none
    }

    struct ToolbarActionViewModel {
        let type: ToolbarAction
        let name: String
        let isEnabled: Bool
    }

    struct ViewState {
        let title: String
        let actions: [ToolbarActionViewModel]
        let snapshot: Snapshot
        let animatingDifferences: Bool = false
    }

    struct AssetSelectionViewModel: Hashable {
        let tokenId: TokenId
        let tokenHolder: TokenHolder
        let selected: Int
        let available: Int
        let isSelected: Bool
        let isSingleSelectionEnabled: Bool
        let name: String

        init(tokenHolder: TokenHolder, tokenId: TokenId) {
            self.tokenId = tokenId
            self.tokenHolder = tokenHolder
            self.isSelected = tokenHolder.isSelected(tokenId: tokenId)
            self.available = tokenHolder.token(tokenId: tokenId)?.value ?? 1
            self.selected = tokenHolder.selectedCount(tokenId: tokenId).flatMap { String($0) }.flatMap { Int($0) } ?? 0
            self.isSingleSelectionEnabled = {
                guard let value = tokenHolder.token(tokenId: tokenId)?.value, value > 1 else {
                    return true
                }
                return false
            }()
            self.name = tokenHolder.name(tokenId: tokenId) ?? "-"
        }
    }

    enum AssetsSelection {
        case item(indexPath: IndexPath)
        case all(section: Int)
        case allAvailable
        case unselectAll
    }

    struct SelectedAsset: Equatable {
        let selected: Int
        let indexPath: IndexPath
    }

    enum functional { }

    enum ToolbarAction: CaseIterable {
        case clear
        case selectAll
        case sell
        case deal
        case send

        var title: String {
            switch self {
            case .clear:
                return R.string.localizable.semifungiblesToolbarClear()
            case .selectAll:
                return R.string.localizable.semifungiblesToolbarSelectAll()
            case .sell:
                return R.string.localizable.semifungiblesToolbarSell()
            case .deal:
                return R.string.localizable.semifungiblesToolbarDeal()
            case .send:
                return R.string.localizable.semifungiblesToolbarSend()
            }
        }
    }
}

fileprivate extension NFTAssetSelectionViewModel.functional {
    static func filter(tokenHolders: [TokenHolder], with filter: NFTAssetSelectionViewModel.AssetFilter) -> [TokenHolderWithItsTokenIds] {
        switch filter {
        case .keyword(let keyword):
            guard var keyword = keyword, keyword.nonEmpty else {
                return tokenHolders.map { TokenHolderWithItsTokenIds(tokenHolder: $0, tokensIds: $0.tokens.map { $0.id }) }
            }
            keyword = keyword.lowercased()

            return tokenHolders.compactMap { tokenHolder -> TokenHolderWithItsTokenIds? in
                let subTokens = tokenHolder.tokens.filter { $0.name.lowercased().contains(keyword) }
                if subTokens.isEmpty {
                    if tokenHolder.name.contains(keyword) {
                        return TokenHolderWithItsTokenIds(tokenHolder: tokenHolder, tokensIds: [])
                    } else {
                        return nil
                    }
                } else {
                    return TokenHolderWithItsTokenIds(tokenHolder: tokenHolder, tokensIds: subTokens.map { $0.id })
                }
            }
        case .none:
            return tokenHolders.map { TokenHolderWithItsTokenIds(tokenHolder: $0, tokensIds: $0.tokens.map { $0.id }) }
        }
    }
}
