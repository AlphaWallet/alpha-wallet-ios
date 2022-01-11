// Copyright DApps Platform Inc. All rights reserved.

import Foundation

struct Favicon {
    static func get(for url: URL?) -> URL? {
        guard let host = url?.host else { return nil }
        let url = URL(string: "https://www.google.com/s2/favicons?sz=256&domain_url=\(host)")
        return url
    }
}
