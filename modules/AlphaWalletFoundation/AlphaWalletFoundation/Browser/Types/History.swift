// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import RealmSwift

final class History: Object {
    @objc dynamic var url: String = ""
    @objc dynamic var title: String = ""
    @objc dynamic var createdAt: Date = Date()
    @objc dynamic var id: String = ""

    convenience init(historyRecord: BrowserHistoryRecord) {
        self.init()
        self.url = historyRecord.url.absoluteString
        self.title = historyRecord.title
        self.createdAt = historyRecord.createdAt
        self.id = historyRecord.id
    }

    override class func primaryKey() -> String? {
        return "id"
    }
}

public struct BrowserHistoryRecord: Hashable {
    public let url: URL
    public let title: String
    public let createdAt: Date
    public let id: String

    init(url: URL, title: String) {
        self.url = url
        self.title = title
        self.createdAt = Date()
        self.id = "\(url)|\(createdAt.timeIntervalSince1970)"
    }

    init(history: History) {
        self.url = URL(string: history.url)!
        self.title = history.title
        self.createdAt = history.createdAt
        self.id = history.id
    }
}
