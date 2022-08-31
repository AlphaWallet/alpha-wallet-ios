// Copyright DApps Platform Inc. All rights reserved.

import Foundation

public enum SearchEngine: Int {
    case google = 0
    case duckDuckGo

    public static var `default`: SearchEngine {
        .duckDuckGo
    } 

    public var host: String {
        switch self {
        case .google:
            return "google.com"
        case .duckDuckGo:
            return "duckduckgo.com"
        }
    }

    public func path(for query: String) -> String {
        switch self {
        case .google:
            return "/search"
        case .duckDuckGo:
            return "/"
        }
    }

    public func queryItems(for query: String) -> [URLQueryItem] {
        switch self {
        case .google, .duckDuckGo: return [URLQueryItem(name: "q", value: query)]
        }
    }
}
