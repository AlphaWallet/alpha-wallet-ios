// Copyright DApps Platform Inc. All rights reserved.

import Foundation

public final class BrowserURLParser {
    private static let urlRegEx = try? NSRegularExpression(pattern: "^(http(s)?://)?[a-z0-9-_]+(\\.[a-z0-9-_]+)+(/)?", options: .caseInsensitive)
    private let validSchemes = ["http", "https"]
    public let engine: SearchEngine

    public init(
        engine: SearchEngine = .default
    ) {
        self.engine = engine
    }

    /// Determines if a string is an address or a search query and returns the appropriate URL.
    public func url(from string: String) -> URL? {
        guard let regex = BrowserURLParser.urlRegEx else { return nil }
        let range = NSRange(string.startIndex ..< string.endIndex, in: string)
        if regex.firstMatch(in: string, options: .anchored, range: range) != nil {
            if !validSchemes.contains(where: { string.hasPrefix("\($0)://") }) {
                return URL(string: "http://" + string)
            } else {
                return URL(string: string)
            }
        }

        return buildSearchURL(for: string)
    }

    /// Builds a search URL from a search query string.
    public func buildSearchURL(for query: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = engine.host
        components.path = engine.path(for: query)
        components.queryItems = engine.queryItems(for: query)
        return try! components.asURL()
    }
}
