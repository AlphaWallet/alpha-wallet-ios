// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation
import Combine

struct DappsHomeViewViewModelInput {
    let deleteBookmark: AnyPublisher<BookmarkObject, Never>
}

struct DappsHomeViewViewModelOutput {
    let viewState: AnyPublisher<BrowserHomeViewModel.ViewState, Never>
}

class BrowserHomeViewModel {
    private let bookmarksStore: BookmarksStore
    private var cancelable = Set<AnyCancellable>()

    init(bookmarksStore: BookmarksStore) {
        self.bookmarksStore = bookmarksStore
    }

    func transform(input: DappsHomeViewViewModelInput) -> DappsHomeViewViewModelOutput {
        input.deleteBookmark
            .sink { [bookmarksStore] in bookmarksStore.delete(bookmark: $0) }
            .store(in: &cancelable)

        let viewState = bookmarksStore.bookmarksChangeset
            .map { changeSet -> [BookmarkObject] in
                switch changeSet {
                case .initial(let results): return Array(results)
                case .error: return []
                case .update(let results, _, _, _): return Array(results)
                }
            }.map { $0.map { DappViewCellViewModel(bookmark: $0) }.uniqued() }
            .map { self.buildSnapshot(for: $0) }
            .map { BrowserHomeViewModel.ViewState(snapshot: $0) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState)
    }

    private func buildSnapshot(for viewModels: [DappViewCellViewModel]) -> BrowserHomeViewModel.Snapshot {
        var snapshot = NSDiffableDataSourceSnapshot<BrowserHomeViewModel.Section, DappViewCellViewModel>()
        snapshot.appendSections([.bookmarks])
        snapshot.appendItems(viewModels, toSection: .bookmarks)

        return snapshot
    }
}

extension BrowserHomeViewModel {
    typealias Snapshot = NSDiffableDataSourceSnapshot<BrowserHomeViewModel.Section, DappViewCellViewModel>
    typealias DataSource = UICollectionViewDiffableDataSource<BrowserHomeViewModel.Section, DappViewCellViewModel>

    enum Section: Int, CaseIterable {
        case bookmarks
    }

    struct ViewState {
        let animatingDifferences: Bool = false
        let snapshot: BrowserHomeViewModel.Snapshot
    }
}

