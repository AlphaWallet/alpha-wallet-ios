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
    
    public var firstHistoryRecord: BrowserHistoryRecord? {
        histories.first
    }

    private var histories: [BrowserHistoryRecord] {
        return realm.objects(History.self)
            .sorted(byKeyPath: "createdAt", ascending: false)
            .map { BrowserHistoryRecord(history: $0) }
    }

    public init(realm: Realm = .shared(), ignoreUrls: Set<URL>) {
        self.realm = realm
        self.ignoreUrls = ignoreUrls
    }

    public func addRecord(url: URL, title: String) {
        let record = BrowserHistoryRecord(url: url, title: title)

        guard !ignoreUrls.contains(record.url) else { return }

        add(records: [record])
    }

    func add(records: [BrowserHistoryRecord]) {
        try? realm.safeWrite {
            let records = records.map { History(historyRecord: $0) }
            realm.add(records, update: .all)
        }
    }

    public func delete(record: BrowserHistoryRecord) {
        try? realm.safeWrite {
            guard let record = realm.object(ofType: History.self, forPrimaryKey: record.id) else { return }
            realm.delete(record)
        }
    }

    public func deleteAllRecords() {
        try? realm.safeWrite {
            let histories = realm.objects(History.self)
            realm.delete(histories)
        }
    }
}
