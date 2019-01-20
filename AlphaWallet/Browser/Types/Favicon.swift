// Copyright DApps Platform Inc. All rights reserved.

import Foundation

struct Favicon {
    static func get(for url: URL?) -> URL? {
        guard let host = url?.host else { return nil }
        return URL(string: "https://api.faviconkit.com/\(host)/144")
    }
}
