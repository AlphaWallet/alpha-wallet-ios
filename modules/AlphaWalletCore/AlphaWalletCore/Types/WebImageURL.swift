//
//  AlphaWalletURL.swift
//  AlphaWalletCore
//
//  Created by Vladyslav Shepitko on 11.02.2022.
//

import Foundation

public enum GoogleContentSize: Equatable {
    case s120
    case s128
    case s250
    case s300
    case s750
    case s2500
    case custom(string: String)

    public var rawValue: String {
        switch self {
        case .s120: return "=s120"
        case .s128: return "=s128"
        case .s250: return "=s250"
        case .s300: return "=s300"
        case .s750: return "=s750"
        case .s2500: return "=s2500"
        case .custom(let string): return string
        }
    }

    init?(string: String) {
        guard let rawValue = WebImageURL.functional.googleContentSizeRawValue(for: string) else { return nil }
        let string = rawValue.rawValue.lowercased()

        switch string {
        case "=s120": self = .s120
        case "=s128": self = .s128
        case "=s250": self = .s250
        case "=s300": self = .s300
        case "=s750": self = .s750
        case "=s2500": self = .s2500
        default: self = .custom(string: string)
        }
    }

}

public enum WebImageURL: Codable, Hashable, Equatable, CustomStringConvertible {
    case origin(URL)
    case googleContentRewritten(URL)
    case ipfs(URL)

    public var absoluteString: String {
        return url.absoluteString
    }

    public var description: String {
        return absoluteString
    }

    public var url: URL {
        switch self {
        case .origin(let uRL):
            return uRL
        case .googleContentRewritten(let uRL):
            return uRL
        case .ipfs(let uRL):
            return uRL
        }
    }

    public var googleContentSizeIfAvailable: GoogleContentSize? {
        switch self {
        case .origin, .ipfs:
            return nil
        case .googleContentRewritten(let uRL):
            return WebImageURL.functional.googleContentSize(for: uRL)
        }
    }

    public init?(string: String, withUrlRewriting: Bool = true, rewriteGoogleContentSizeUrl size: GoogleContentSize = .s750) {
        guard let url = URL(string: string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).replacingOccurrences(of: " ", with: "%20")) else {
            return nil
        }
        self.init(url: url, withUrlRewriting: withUrlRewriting, rewriteGoogleContentSizeUrl: size)
    }

    public init(url: URL, withUrlRewriting: Bool = true, rewriteGoogleContentSizeUrl size: GoogleContentSize = .s750) {
        if let url = WebImageURL.functional.rewriteGoogleContentSizeUrl(url: url, size: size), withUrlRewriting {
            self = .googleContentRewritten(url)
        } else if let url = url.rewriteIfIpfsOrNil, withUrlRewriting {
            self = .ipfs(url)
        } else {
            self = .origin(url)
        }
    }
}

extension String {

    func rangeFromNSRange(nsRange: NSRange) -> Range<String.Index>? {
        return Range(nsRange, in: self)
    }
}

extension WebImageURL {
    enum functional { }
}

fileprivate extension WebImageURL.functional {
    static let googleImageSizeInUrlRegex: NSRegularExpression = {
        return try! NSRegularExpression(pattern: "(=s|=S).*[0-9]", options: .init())
    }()

    static func googleContentSizeRawValue(for string: String) -> (rawValue: String, range: Range<String.Index>)? {
        let result = googleImageSizeInUrlRegex.matches(in: string, range: NSRange(string.startIndex..., in: string))
        if let check = result.last, let range = string.rangeFromNSRange(nsRange: check.range) {
            return (String(string[range]), range)
        } else {
            return nil
        }
    }

    static func googleContentSize(for url: URL, hostSuffix: String = "googleusercontent.com") -> GoogleContentSize? {
        guard let components = URLComponents(string: url.absoluteString), let host = components.host, host.hasSuffix(hostSuffix) else {
            return nil
        }

        return googleContentSizeRawValue(for: components.path)
            .flatMap { GoogleContentSize(string: $0.rawValue) }
    }

    //NOTE: search only for matching of `=s750` values for overriding only actual size, without rewriting other image flags
    static func rewriteGoogleContentSizeUrl(url: URL, size: GoogleContentSize, hostSuffix: String = "googleusercontent.com") -> URL? {
        guard var components = URLComponents(string: url.absoluteString), let host = components.host, host.hasSuffix(hostSuffix) else {
            return nil
        }

        let path = components.path
        guard let (_, range) = googleContentSizeRawValue(for: path) else { return nil }
        components.path = path.replacingCharacters(in: range, with: size.rawValue)

        return components.url
    }
}
