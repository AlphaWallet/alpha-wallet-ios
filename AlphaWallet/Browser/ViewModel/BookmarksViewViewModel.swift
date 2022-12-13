// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Foundation
import AlphaWalletFoundation
import Combine

struct BookmarksViewModelInput {
    let deleteBookmark: AnyPublisher<BookmarkObject, Never>
    let reorderBookmarks: AnyPublisher<(from: IndexPath, to: IndexPath), Never>
}

struct BookmarksViewModelOutput {
    let viewState: AnyPublisher<BookmarksViewViewModel.ViewState, Never>
}

class BookmarksViewViewModel {
    private let bookmarksStore: BookmarksStore
    private var cancelable = Set<AnyCancellable>()

    let headerViewModel = BrowserHomeHeaderViewModel(title: R.string.localizable.myDappsButtonImageLabel())
    lazy var emptyViewModel: DappsHomeEmptyViewModel = {
        return DappsHomeEmptyViewModel(headerViewViewModel: headerViewModel, title: R.string.localizable.dappBrowserMyDappsEmpty())
    }()
    
    init(bookmarksStore: BookmarksStore) {
        self.bookmarksStore = bookmarksStore
    }

    func moveBookmark(fromIndex from: Int, toIndex to: Int) {
        bookmarksStore.moveBookmark(fromIndex: from, toIndex: to)
    }

    func transform(input: BookmarksViewModelInput) -> BookmarksViewModelOutput {
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
            }.map { $0.map { MyDappCellViewModel(bookmark: $0) }.uniqued() }
            .map { self.buildSnapshot(for: $0) }
            .map { BookmarksViewViewModel.ViewState(snapshot: $0) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState)
    }

    private func buildSnapshot(for viewModels: [MyDappCellViewModel]) -> BookmarksViewViewModel.Snapshot {
        var snapshot = NSDiffableDataSourceSnapshot<BookmarksViewViewModel.Section, MyDappCellViewModel>()
        snapshot.appendSections([.bookmarks])
        snapshot.appendItems(viewModels, toSection: .bookmarks)

        return snapshot
    }
}

extension BookmarksViewViewModel {
    typealias Snapshot = NSDiffableDataSourceSnapshot<BookmarksViewViewModel.Section, MyDappCellViewModel>
    typealias DataSource = UITableViewDiffableDataSource<BookmarksViewViewModel.Section, MyDappCellViewModel>
    
    enum Section: Int, CaseIterable {
        case bookmarks
    }

    struct ViewState {
        let snapshot: BookmarksViewViewModel.Snapshot
        let animatingDifferences: Bool = false
    }
}
