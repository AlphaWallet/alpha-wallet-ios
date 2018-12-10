// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct MyDappsViewControllerViewModel {
    var bookmarksStore: BookmarksStore

    var dappsCount: Int {
        return bookmarksStore.bookmarks.count
    }

    var hasContent: Bool {
        return !bookmarksStore.bookmarks.isEmpty
    }

    func dapp(atIndex index: Int) -> Bookmark {
        return bookmarksStore.bookmarks[index]
    }
}
