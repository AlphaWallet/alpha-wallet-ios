//
//  ConsoleViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.11.2022.
//

import Foundation
import UIKit
import AlphaWalletFoundation
import Combine

struct ConsoleViewModelInput {
    let willAppear: AnyPublisher<Void, Never>
}

struct ConsoleViewModelOutput {
    let viewState: AnyPublisher<ConsoleViewModel.ViewState, Never>
}

class ConsoleViewModel {
    private let assetDefinitionStore: AssetDefinitionStore
    private var cancelable = Set<AnyCancellable>()

    init(assetDefinitionStore: AssetDefinitionStore) {
        self.assetDefinitionStore = assetDefinitionStore
    }

    func transform(input: ConsoleViewModelInput) -> ConsoleViewModelOutput {

        let listOfBadTokenScriptFiles = assetDefinitionStore.listOfBadTokenScriptFiles
            .map { $0.map { "\($0) is invalid" } }

        let conflictingTokenScriptFileNames = Just(assetDefinitionStore.conflictingTokenScriptFileNames)
            .map { conflicting -> [String] in
                let conflictsInOfficialSource = conflicting.official.map { "[Repo] \($0) has a conflict" }
                let conflictsInOverrides = conflicting.overrides.map { "[Overrides] \($0) has a conflict" }
                return conflictsInOfficialSource + conflictsInOverrides
            }

        let viewModels = Publishers.CombineLatest(listOfBadTokenScriptFiles, conflictingTokenScriptFileNames)
            .map { Array(Set($0.0 + $0.1)) }
            .map { SectionViewModel(section: .messages, views: $0) }
            .map { self.buildSnapshot(for: [$0]) }

        let viewState = viewModels
            .map { snapshot -> ConsoleViewModel.ViewState in
                return ConsoleViewModel.ViewState(snapshot: snapshot)
            }.eraseToAnyPublisher()

        return .init(viewState: viewState)
    }

    private func buildSnapshot(for viewModels: [SectionViewModel]) -> ConsoleViewModel.Snapshot {
        var snapshot = NSDiffableDataSourceSnapshot<ConsoleViewModel.Section, ConsoleMessage>()
        let sections = viewModels.map { $0.section }
        snapshot.appendSections(sections)
        for each in viewModels {
            snapshot.appendItems(each.views, toSection: each.section)
        }

        return snapshot
    }
}

extension ConsoleViewModel {
    typealias ConsoleMessage = String
    typealias Snapshot = NSDiffableDataSourceSnapshot<ConsoleViewModel.Section, ConsoleMessage>
    typealias DataSource = UITableViewDiffableDataSource<ConsoleViewModel.Section, ConsoleMessage>

    struct ViewState {
        let snapshot: ConsoleViewModel.Snapshot
        let animatingDifferences: Bool = false
        let title: String = R.string.localizable.aConsoleTitle()
    }

    struct SectionViewModel {
        let section: ConsoleViewModel.Section
        let views: [ConsoleMessage]
    }

    enum Section: Int, Hashable, CaseIterable {
        case messages
    }
}
