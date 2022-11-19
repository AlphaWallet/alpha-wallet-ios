// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import RealmSwift
import Combine

public final class BrowserHistoryStorage {
    private let realm: Realm
    private let ignoreUrls: Set<URL>

    public var historiesChangeset: AnyPublisher<ChangeSet<[BrowserHistoryRecord]>, Never> {
        return realm.objects(History.self)
            .sorted(byKeyPath: "createdAt", ascending: false)
            .changesetPublisher
            .map { changeSet -> ChangeSet<[BrowserHistoryRecord]> in
                switch changeSet {
                case .initial(let results):
                    return .initial(Array(results.map { BrowserHistoryRecord(history: $0) }))
                case .error(let error):
                    return .error(error)
                case .update(let results, let deletions, let insertions, let modifications):
                    return .update(Array(results.map { BrowserHistoryRecord(history: $0) }), deletions: deletions, insertions: insertions, modifications: modifications)
                }
            }.eraseToAnyPublisher()
    }

    public var histories: [BrowserHistoryRecord] {
        return realm.objects(History.self)
            .sorted(byKeyPath: "createdAt", ascending: false)
            .map { BrowserHistoryRecord(history: $0) }
    }

    public init(realm: Realm = .shared(), ignoreUrls: Set<URL>) {
        self.realm = realm
        self.ignoreUrls = ignoreUrls
    }

    public func addRecord(url: URL, title: String) {
        let history = BrowserHistoryRecord(url: url, title: title)

        guard !ignoreUrls.contains(history.url) else { return }

        add(histories: [history])
    }

    func add(histories: [BrowserHistoryRecord]) {
        try? realm.write {
            let records = histories.map { History(historyRecord: $0) }
            realm.add(records, update: .all)
        }
    }

    public func delete(histories: [BrowserHistoryRecord]) {
        try? realm.write {
            let records = histories.map { History(historyRecord: $0) }
            realm.delete(records)
        }
    }

    public func clearAll() {
        try? realm.write {
            let histories = realm.objects(History.self)
            realm.delete(histories)
        }
    }
}
