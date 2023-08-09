// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import RealmSwift
import Combine

public final class BookmarksStore {
    private var bookmarks: Results<Bookmark> {
        return realm.objects(Bookmark.self)
            .sorted(byKeyPath: "order", ascending: true)
    }
    //TODO should use a RealmStore.performInBackground or similar
    private let realm: Realm

    public var bookmarksChangeset: AnyPublisher<ChangeSet<[BookmarkObject]>, Never> {
        //TODO speed up. why doesn't this use performSync?
        return realm.objects(Bookmark.self)
            .sorted(byKeyPath: "order", ascending: true)
            .changesetPublisher
            .map { changeSet -> ChangeSet<[BookmarkObject]> in
                switch changeSet {
                case .initial(let results):
                    return .initial(Array(results.map { BookmarkObject(bookmark: $0) }))
                case .error(let error):
                    return .error(error)
                case .update(let results, let deletions, let insertions, let modifications):
                    return .update(Array(results.map { BookmarkObject(bookmark: $0) }), deletions: deletions, insertions: insertions, modifications: modifications)
                }
            }.eraseToAnyPublisher()
    }

    public init(realm: Realm = .shared()) {
        self.realm = realm
    }

    public func update(bookmark: BookmarkObject, title: String, url: String) {
        try? realm.safeWrite {
            let bookmark = Bookmark(bookmark: bookmark)
            bookmark.title = title
            bookmark.url = url

            realm.add(bookmark, update: .all)
        }
    }

    public func add(bookmarks: [BookmarkObject]) {
        var bookmarkOrder = self.bookmarks.count
        try? realm.safeWrite {
            let bookmarks = bookmarks.map { Bookmark(bookmark: $0) }
            for each in bookmarks {
                each.order = bookmarkOrder
                bookmarkOrder += 1
            }
            realm.add(bookmarks, update: .all)
        }
    }

    public func delete(bookmark: BookmarkObject) {
        try? realm.safeWrite {
            guard let bookmark = realm.object(ofType: Bookmark.self, forPrimaryKey: bookmark.id) else { return }
            realm.delete(bookmark)
            for (index, each) in Array(bookmarks).enumerated() {
                each.order = index
            }
        }
    }

    public func moveBookmark(fromIndex from: Int, toIndex to: Int) {
        try? realm.safeWrite {
            let bookmarkMoved = bookmarks[from]
            if from < to {
                let changed = bookmarks[(from+1)...to]
                for each in changed {
                    each.order -= 1
                }
            } else {
                let changed = bookmarks[to..<from]
                //`Array` is essential for this to work. Otherwise when accessing `each`, we may change the same bookmark twice when we reorder in a certain direction (up or down). Maybe a Realm oddity
                for each in Array(changed) {
                    each.order += 1
                }
            }
            bookmarkMoved.order = to
        }
    }
}
