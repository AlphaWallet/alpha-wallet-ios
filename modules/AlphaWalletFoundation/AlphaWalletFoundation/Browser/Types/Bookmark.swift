// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import RealmSwift

public final class Bookmark: Object {
    @objc public dynamic var url: String = ""
    @objc public dynamic var title: String = ""
    @objc public dynamic var id: String = UUID().uuidString
    @objc public dynamic var createdAt: Date = Date()
    @objc public dynamic var order: Int = 0

    public convenience init(bookmark: BookmarkObject) {
        self.init()
        self.url = bookmark.url?.absoluteString ?? ""
        self.title = bookmark.title
        self.createdAt = bookmark.createdAt
        self.order = bookmark.order
    }

    public var linkURL: URL? {
        return URL(string: url)
    }

    public override class func primaryKey() -> String? {
        return "id"
    }
}

public struct BookmarkObject: Hashable, Equatable {
    public let url: URL?
    public let title: String
    public let id: String
    public let createdAt: Date
    public let order: Int

    public init(url: String = "", title: String = "") {
        self.url = URL(string: url)
        self.title = title
        self.id = UUID().uuidString
        self.createdAt = Date()
        self.order = 0
    }

    public init(bookmark: Bookmark) {
        self.id = bookmark.id
        self.url = URL(string: bookmark.url)
        self.title = bookmark.title
        self.createdAt = bookmark.createdAt
        self.order = bookmark.order
    }
}
