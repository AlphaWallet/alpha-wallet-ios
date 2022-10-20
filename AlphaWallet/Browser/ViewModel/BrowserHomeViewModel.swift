// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation
import Combine

struct DappsHomeViewViewModelInput {
    let deleteBookmark: AnyPublisher<IndexPath, Never>
}

struct DappsHomeViewViewModelOutput {
    let viewState: AnyPublisher<BrowserHomeViewModel.ViewState, Never>
}

class BrowserHomeViewModel {
    private let bookmarksStore: BookmarksStore
    private var bookmarks: [Bookmark] = []
    private var cancelable = Set<AnyCancellable>()

    init(bookmarksStore: BookmarksStore) {
        self.bookmarksStore = bookmarksStore
    }

    func bookmark(at index: Int) -> Bookmark {
        return bookmarks[index]
    }

    var backgroundColor: UIColor {
        return Configuration.Color.Semantic.defaultViewBackground
    }

    func transform(input: DappsHomeViewViewModelInput) -> DappsHomeViewViewModelOutput {
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
            .map { $0.map { DappViewCellViewModel(dapp: $0) } }
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

    enum Section: Int, CaseIterable {
        case bookmarks
    }

    struct ViewState {
        let snapshot: BrowserHomeViewModel.Snapshot
    }
}

