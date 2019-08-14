// Copyright DApps Platform Inc. All rights reserved.

import Foundation

struct HistoriesViewModel {
    private let store: HistoryStore

    init(store: HistoryStore) {
        self.store = store
    }

    var hasContent: Bool {
        return !store.histories.isEmpty
    }

    var numberOfRows: Int {
        return store.histories.count
    }

    func item(for indexPath: IndexPath) -> History {
        return store.histories[indexPath.row]
    }
}
