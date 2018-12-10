// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct DappsHomeViewControllerViewModel {
    var bookmarksStore: BookmarksStore

    var dappsCount: Int {
        return bookmarksStore.bookmarks.count
    }

    func dapp(atIndex index: Int) -> Bookmark {
        return bookmarksStore.bookmarks[index]
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }
}