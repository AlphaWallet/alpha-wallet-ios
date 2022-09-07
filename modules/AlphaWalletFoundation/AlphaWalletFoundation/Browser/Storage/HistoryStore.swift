// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import RealmSwift

public final class  HistoryStore {
    private let realm: Realm

    public var histories: Results<History> {
        return realm.objects(History.self)
            .sorted(byKeyPath: "createdAt", ascending: false)
    }

    public init(realm: Realm) {
        self.realm = realm
    }

    public  lazy var ignoreSet: Set<String> = {
        let set = Set<String>([
            Constants.dappsBrowserURL,
        ])
        return set
    }()

    public func record(url: URL, title: String) {
        let history = History(url: url.absoluteString, title: title)

        guard !ignoreSet.contains(history.url) else {
            return
        }

        add(histories: [history])
    }

    public func add(histories: [History]) {
        try? realm.write {
            realm.add(histories, update: .all)
        }
    }

    public func delete(histories: [History]) {
        try? realm.write {
            realm.delete(histories)
        }
    }

    public func clearAll() {
        try? realm.write {
            realm.delete(histories)
        }
    }
}
