//
//  AssetDefinitionsOverridesViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 29.11.2022.
//

import Foundation
import UIKit
import AlphaWalletFoundation
import Combine

struct AssetDefinitionsOverridesViewModelInput {
    let willAppear: AnyPublisher<Void, Never>
    let deletion: AnyPublisher<URL, Never>
}

struct AssetDefinitionsOverridesViewModelOutput {
    let viewState: AnyPublisher<AssetDefinitionsOverridesViewModel.ViewState, Never>
}

class AssetDefinitionsOverridesViewModel {
    private let tokenScriptOverridesFileManager: TokenScriptOverridesFileManager
    private let fileExtension: String
    private var cancelable = Set<AnyCancellable>()

    init(tokenScriptOverridesFileManager: TokenScriptOverridesFileManager, fileExtension: String) {
        self.fileExtension = fileExtension
        self.tokenScriptOverridesFileManager = tokenScriptOverridesFileManager
    }

    func transform(input: AssetDefinitionsOverridesViewModelInput) -> AssetDefinitionsOverridesViewModelOutput {
        input.deletion
            .sink { [tokenScriptOverridesFileManager] in tokenScriptOverridesFileManager.remove(overrideFile: $0) }
            .store(in: &cancelable)

        let viewModels = input.willAppear
            .flatMapLatest { [tokenScriptOverridesFileManager] _ in tokenScriptOverridesFileManager.overrides }
            .map { [fileExtension] in $0.map { AssetDefinitionsOverridesViewCellViewModel(url: $0, fileExtension: fileExtension) } }
            .map { SectionViewModel(section: .overrides, views: $0) }
            .map { self.buildSnapshot(for: [$0]) }
            .eraseToAnyPublisher()

        let viewState = viewModels
            .map { snapshot -> AssetDefinitionsOverridesViewModel.ViewState in
                return AssetDefinitionsOverridesViewModel.ViewState(snapshot: snapshot)
            }.eraseToAnyPublisher()

        return .init(viewState: viewState)
    }

    private func buildSnapshot(for viewModels: [AssetDefinitionsOverridesViewModel.SectionViewModel]) -> AssetDefinitionsOverridesViewModel.Snapshot {
        var snapshot = AssetDefinitionsOverridesViewModel.Snapshot()
        let sections = viewModels.map { $0.section }
        snapshot.appendSections(sections)
        for each in viewModels {
            snapshot.appendItems(each.views, toSection: each.section)
        }

        return snapshot
    }
}

extension AssetDefinitionsOverridesViewModel {
    typealias Snapshot = NSDiffableDataSourceSnapshot<AssetDefinitionsOverridesViewModel.Section, AssetDefinitionsOverridesViewCellViewModel>
    typealias DataSource = UITableViewDiffableDataSource<AssetDefinitionsOverridesViewModel.Section, AssetDefinitionsOverridesViewCellViewModel>

    struct ViewState {
        let snapshot: AssetDefinitionsOverridesViewModel.Snapshot
        let animatingDifferences: Bool = false
        let title: String = R.string.localizable.aHelpAssetDefinitionOverridesTitle()
    }

    struct SectionViewModel {
        let section: AssetDefinitionsOverridesViewModel.Section
        let views: [AssetDefinitionsOverridesViewCellViewModel]
    }

    enum Section: Int, Hashable, CaseIterable {
        case overrides
    }
}

