// Copyright DApps Platform Inc. All rights reserved.

import Foundation

enum SearchEngine: Int {
    case google = 0
    case duckDuckGo

    static var `default`: SearchEngine {
        .duckDuckGo
    }

    var title: String {
        switch self {
        case .google:
            return R.string.localizable.google()
        case .duckDuckGo:
            return R.string.localizable.duckDuckGo()
        }
    }

    var host: String {
        switch self {
        case .google:
            return "google.com"
        case .duckDuckGo:
            return "duckduckgo.com"
        }
    }

    func path(for query: String) -> String {
        switch self {
        case .google:
            return "/search"
        case .duckDuckGo:
            return "/"
        }
    }

    func queryItems(for query: String) -> [URLQueryItem] {
        switch self {
        case .google, .duckDuckGo: return [URLQueryItem(name: "q", value: query)]
        }
    }
}
