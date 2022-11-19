// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Foundation
import AlphaWalletFoundation
import Combine

struct BookmarksViewModelInput {
    let deleteBookmark: AnyPublisher<IndexPath, Never>
    let reorderBookmarks: AnyPublisher<(from: IndexPath, to: IndexPath), Never>
}

struct BookmarksViewModelOutput {
    let viewState: AnyPublisher<BookmarksViewViewModel.ViewState, Never>
}

class BookmarksViewViewModel {
    private let bookmarksStore: BookmarksStore
    private var bookmarks: [Bookmark] = []
    private var cancelable = Set<AnyCancellable>()
    let headerViewModel = BrowserHomeHeaderViewModel(title: R.string.localizable.myDappsButtonImageLabel())
    lazy var emptyViewModel: DappsHomeEmptyViewModel = {
        return DappsHomeEmptyViewModel(headerViewViewModel: headerViewModel, title: R.string.localizable.dappBrowserMyDappsEmpty())
    }()
    
    init(bookmarksStore: BookmarksStore) {
        self.bookmarksStore = bookmarksStore
    }

    var dappsCount: Int {
        return bookmarksStore.bookmarks.count
    }

    var hasContent: Bool {
        return !bookmarksStore.bookmarks.isEmpty
    }

    func bookmark(at index: Int) -> Bookmark {
        return bookmarksStore.bookmarks[index]
    }

    func moveBookmark(fromIndex from: Int, toIndex to: Int) {
        bookmarksStore.moveBookmark(fromIndex: from, toIndex: to)
    }

    func transform(input: BookmarksViewModelInput) -> BookmarksViewModelOutput {
        input.deleteBookmark
            .sink { [bookmarksStore] indexPath in
                let bookmark = self.bookmarks[indexPath.row]
                bookmarksStore.delete(bookmarks: [bookmark])
            }.store(in: &cancelable)

        let bookmarks = bookmarksStore.bookmarks
            .changesetPublisher
            .map { changeSet -> [Bookmark] in
                switch changeSet {
                case .initial(let results): return Array(results)
                case .error: return []
                case .update(let results, _, _, _): return Array(results)
                }
            }.handleEvents(receiveOutput: { self.bookmarks = $0 })

        let viewState = bookmarks
            .map { $0.map { MyDappCellViewModel(dapp: $0) } }
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
