//
//  SelectedSwapToolsCollectionViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.09.2022.
//

import Foundation
import AlphaWalletFoundation
import Combine
import UIKit

struct SelectedSwapToolsCollectionViewModelInput {
    let appear: AnyPublisher<Void, Never>
}

struct SelectedSwapToolsCollectionViewModelOutput {
    let viewState: AnyPublisher<SelectedSwapToolsCollectionViewModel.ViewState, Never>
}

class SelectedSwapToolsCollectionViewModel {
    private var storage: SwapToolStorage
    
    var backgroundColor: UIColor = Colors.appWhite

    init(storage: SwapToolStorage) {
        self.storage = storage
    }

    func transform(input: SelectedSwapToolsCollectionViewModelInput) -> SelectedSwapToolsCollectionViewModelOutput {
        let appear = input.appear
            .flatMapLatest { [storage] _ in storage.selectedTools.first() }

        let viewState = Publishers.Merge(appear, storage.selectedTools)
            .removeDuplicates()
            .map { tools -> ToolsSnapshot in
                let viewModels = tools.map { SwapToolCollectionViewCellViewModel(name: $0.name) }
                var snapshot = ToolsSnapshot()
                snapshot.appendSections(SelectedSwapToolsCollectionViewModel.Section.allCases)
                snapshot.appendItems(viewModels)

                return snapshot
            }.map { SelectedSwapToolsCollectionViewModel.ViewState(tools: $0) }

        return .init(viewState: viewState.eraseToAnyPublisher())
    }
}

extension SelectedSwapToolsCollectionViewModel {
    class ToolsDiffableDataSource: UICollectionViewDiffableDataSource<SelectedSwapToolsCollectionViewModel.Section, SwapToolCollectionViewCellViewModel> {}
    typealias ToolsSnapshot = NSDiffableDataSourceSnapshot<SelectedSwapToolsCollectionViewModel.Section, SwapToolCollectionViewCellViewModel>

    enum Section: Int, Hashable, CaseIterable {
        case tools
    }

    struct ViewState {
        let tools: ToolsSnapshot
    }
}
