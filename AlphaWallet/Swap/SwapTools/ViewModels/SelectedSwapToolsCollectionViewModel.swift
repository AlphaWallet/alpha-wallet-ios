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
    let willAppear: AnyPublisher<Void, Never>
}

struct SelectedSwapToolsCollectionViewModelOutput {
    let viewState: AnyPublisher<SelectedSwapToolsCollectionViewModel.ViewState, Never>
}

class SelectedSwapToolsCollectionViewModel {
    private var storage: SwapToolStorage
    
    init(storage: SwapToolStorage) {
        self.storage = storage
    }

    func transform(input: SelectedSwapToolsCollectionViewModelInput) -> SelectedSwapToolsCollectionViewModelOutput {
        let willAppear = input.willAppear
            .flatMapLatest { [storage] _ in storage.selectedTools.first() }

        let viewState = Publishers.Merge(willAppear, storage.selectedTools)
            .removeDuplicates()
            .map { tools -> Snapshot in
                let viewModels = tools.map { SwapToolCollectionViewCellViewModel(name: $0.name) }
                var snapshot = Snapshot()
                snapshot.appendSections(SelectedSwapToolsCollectionViewModel.Section.allCases)
                snapshot.appendItems(viewModels)

                return snapshot
            }.map { SelectedSwapToolsCollectionViewModel.ViewState(snapshot: $0) }

        return .init(viewState: viewState.eraseToAnyPublisher())
    }
}

extension SelectedSwapToolsCollectionViewModel {
    class DataSource: UICollectionViewDiffableDataSource<SelectedSwapToolsCollectionViewModel.Section, SwapToolCollectionViewCellViewModel> {}
    typealias Snapshot = NSDiffableDataSourceSnapshot<SelectedSwapToolsCollectionViewModel.Section, SwapToolCollectionViewCellViewModel>

    enum Section: Int, Hashable, CaseIterable {
        case tools
    }

    struct ViewState {
        let snapshot: Snapshot
    }
}
