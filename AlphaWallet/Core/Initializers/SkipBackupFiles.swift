// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct SkipBackupFiles: Initializer {

    private var urls: [URL] {
        var paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true).compactMap { URL(fileURLWithPath: $0) }
        paths.append(legacyFileBasedKeystore.keystoreDirectory)
        return paths
    }
    private let legacyFileBasedKeystore: LegacyFileBasedKeystore

    init(legacyFileBasedKeystore: LegacyFileBasedKeystore) {
        self.legacyFileBasedKeystore = legacyFileBasedKeystore
    }

    func perform() {
        urls.forEach { addSkipBackupAttributeToItemAtURL($0) }
    }

    @discardableResult func addSkipBackupAttributeToItemAtURL(_ url: URL) -> Bool {
        let url = NSURL.fileURL(withPath: url.path) as NSURL
        do {
            try url.setResourceValue(true, forKey: .isExcludedFromBackupKey)
            try url.setResourceValue(false, forKey: .isUbiquitousItemKey)
            return true
        } catch {
            return false
        }
    }
}
