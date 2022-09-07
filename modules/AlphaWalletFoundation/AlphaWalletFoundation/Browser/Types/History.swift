// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import RealmSwift

public final class History: Object {
    @objc public dynamic var url: String = ""
    @objc public dynamic var title: String = ""
    @objc public dynamic var createdAt: Date = Date()
    @objc public dynamic var id: String = ""

    public convenience init(url: String, title: String) {
        self.init()
        self.url = url
        self.title = title
        self.id = "\(url)|\(createdAt.timeIntervalSince1970)"
    }

    public var URL: URL? {
        return Foundation.URL(string: url)
    }

    public override class func primaryKey() -> String? {
        return "id"
    }
}
