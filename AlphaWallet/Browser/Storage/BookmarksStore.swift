// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import RealmSwift

final class BookmarksStore {
    var bookmarks: Results<Bookmark> {
        return realm.objects(Bookmark.self)
            .sorted(byKeyPath: "createdAt", ascending: false)
    }
    private let realm: Realm

    init(realm: Realm) {
        self.realm = realm
    }

    private func findOriginalBookmarks(matchingBookmarks bookmarksToFind: [Bookmark]) -> [Bookmark] {
        var originals = [Bookmark]()
        for toDelete in bookmarksToFind {
            var found = false
            for original in bookmarks {
                if original.id == toDelete.id {
                    originals.append(original)
                    found = true
                    break
                }
            }
            if !found {
                for original in bookmarks {
                    if original.url == toDelete.url {
                        originals.append(original)
                        break
                    }
                }
            }
        }
        return originals
    }

    func add(bookmarks: [Bookmark]) {
        realm.beginWrite()
        realm.add(bookmarks, update: true)
        try! realm.commitWrite()
    }

    func delete(bookmarks bookmarksToDelete: [Bookmark]) {
        //We may not receive the original Bookmark object(s), hence the lookup
        let originalsToDelete = findOriginalBookmarks(matchingBookmarks: bookmarksToDelete)

        realm.beginWrite()
        realm.delete(originalsToDelete)
        try! realm.commitWrite()
    }
}
