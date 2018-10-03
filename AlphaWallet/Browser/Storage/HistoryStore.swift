// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import RealmSwift

final class  HistoryStore {
    private let realm: Realm

    var histories: Results<History> {
        return realm.objects(History.self)
            .sorted(byKeyPath: "createdAt", ascending: false)
    }

    init(realm: Realm) {
        self.realm = realm
    }

    lazy var ignoreSet: Set<String> = {
        let set = Set<String>([
            Constants.dappsBrowserURL,
        ])
        return set
    }()

    func record(url: URL, title: String) {
        let history = History(url: url.absoluteString, title: title)

        guard !ignoreSet.contains(history.url) else {
            return
        }

        add(histories: [history])
    }

    func add(histories: [History]) {
        try? realm.write {
            realm.add(histories, update: true)
        }
    }

    func delete(histories: [History]) {
        try? realm.write {
            realm.delete(histories)
        }
    }

    func clearAll() {
        try? realm.write {
            realm.delete(histories)
        }
    }
}
