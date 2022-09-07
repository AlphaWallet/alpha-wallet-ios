// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import RealmSwift

public final class Bookmark: Object {
    @objc public dynamic var url: String = ""
    @objc public dynamic var title: String = ""
    @objc public dynamic var id: String = UUID().uuidString
    @objc public dynamic var createdAt: Date = Date()
    @objc public dynamic var order: Int = 0

    public convenience init(
        url: String = "",
        title: String = ""
    ) {
        self.init()
        self.url = url
        self.title = title
    }

    public var linkURL: URL? {
        return URL(string: url)
    }

    public override class func primaryKey() -> String? {
        return "id"
    }
}
