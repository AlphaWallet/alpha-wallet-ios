//
//  ConnectionUrl.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 31.08.2022.
//

import Foundation

extension AlphaWallet {

    public enum WalletConnect {

        public enum ConnectionUrl: Codable {
            case v1(wcUrl: WalletConnectV1URL)
            case v2(uri: WalletConnectV2URI)

            struct ConnectionUrlError: Error {}

            private enum Keys: CodingKey {
                case url
                case uri
            }

            public var absoluteString: String {
                switch self {
                case .v1(let wcUrl):
                    return wcUrl.absoluteString
                case .v2(let uri):
                    return uri.absoluteString
                }
            }

            public init?(_ string: String) {
                if let v2 = WalletConnectV2URI(string: string) {
                    self = .v2(uri: v2)
                } else if let v1 = WalletConnectV1URL(string) {
                    self = .v1(wcUrl: v1)
                } else {
                    return nil
                }
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: Keys.self)
                if let rawValue = try? container.decode(String.self, forKey: .url), let value = ConnectionUrl(rawValue) {
                    self = value
                } else {
                    throw ConnectionUrlError()
                }
            }

            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: Keys.self)
                try container.encode(absoluteString, forKey: .url)
            }
        }
    }
}

public struct WalletConnectV1URL: Hashable, Codable {
    // topic is used for handshake only
    public var topic: String
    public var version: String
    public var bridgeURL: URL
    public var key: String

    public var absoluteString: String {
        let bridge = bridgeURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
        return "wc:\(topic)@\(version)?bridge=\(bridge)&key=\(key)"
    }

    public init(topic: String,
                version: String = "1",
                bridgeURL: URL,
                key: String) {
        self.topic = topic
        self.version = version
        self.bridgeURL = bridgeURL
        self.key = key
    }

    public init?(_ str: String) {
        guard str.hasPrefix("wc:") else {
            return nil
        }
        let urlStr = !str.hasPrefix("wc://") ? str.replacingOccurrences(of: "wc:", with: "wc://") : str
        guard let url = URL(string: urlStr),
            let topic = url.user,
            let version = url.host,
            let components = NSURLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return nil
        }
        var dict = [String: String]()
        for query in components.queryItems ?? [] {
            if let value = query.value {
                dict[query.name] = value
            }
        }
        guard let bridge = dict["bridge"],
            let bridgeUrl = URL(string: bridge),
            let key = dict["key"] else {
                return nil
        }
        self.topic = topic
        self.version = version
        self.bridgeURL = bridgeUrl
        self.key = key
    }
}

struct _RelayProtocolOptions: Codable, Equatable {
    let `protocol`: String
    let data: String?
}

public struct WalletConnectV2URI: Equatable {

    let topic: String
    let version: String
    let symKey: String
    let relay: _RelayProtocolOptions

    init(topic: String, symKey: String, relay: _RelayProtocolOptions) {
        self.version = "2"
        self.topic = topic
        self.symKey = symKey
        self.relay = relay
    }

    public init?(string: String) {
        guard string.hasPrefix("wc:") else {
            return nil
        }
        let urlString = !string.hasPrefix("wc://") ? string.replacingOccurrences(of: "wc:", with: "wc://") : string
        guard let components = URLComponents(string: urlString) else {
            return nil
        }
        let query: [String: String]? = components.queryItems?.reduce(into: [:]) { $0[$1.name] = $1.value }

        guard let topic = components.user,
              let version = components.host,
              let symKey = query?["symKey"],
              let relayProtocol = query?["relay-protocol"]
        else { return nil }
        let relayData = query?["relay-data"]
        self.version = version
        self.topic = topic
        self.symKey = symKey
        self.relay = _RelayProtocolOptions(protocol: relayProtocol, data: relayData)
    }

    public var absoluteString: String {
        return "wc:\(topic)@\(version)?symKey=\(symKey)&\(relayQuery)"
    }

    private var relayQuery: String {
        var query = "relay-protocol=\(relay.protocol)"
        if let relayData = relay.data {
            query = "\(query)&relay-data=\(relayData)"
        }
        return query
    }
}
