//
//  WalletConnectV2URI.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.11.2021.
//

import Foundation

internal struct WalletConnectV2URI: Hashable, Equatable, Codable {

    let topic: String
    let version: String
    let publicKey: String
    let isController: Bool
    let relay: RelayProtocolOptions

    func hash(into hasher: inout Hasher) {
        hasher.combine(topic)
        hasher.combine(version)
        hasher.combine(publicKey)
        hasher.combine(isController)
        hasher.combine(relay)
    }

    init(topic: String, publicKey: String, isController: Bool, relay: RelayProtocolOptions) {
        self.version = "2"
        self.topic = topic
        self.publicKey = publicKey
        self.isController = isController
        self.relay = relay
    }

    init?(_ string: String) {
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
              let publicKey = query?["publicKey"],
              let isController = Bool(query?["controller"] ?? ""),
              let relayOptions = query?["relay"],
              let relay = try? JSONDecoder().decode(RelayProtocolOptions.self, from: Data(relayOptions.utf8))
        else { return nil }

        self.version = version
        self.topic = topic
        self.publicKey = publicKey
        self.isController = isController
        self.relay = relay
    }

    var absoluteString: String {
        return "wc:\(topic)@\(version)?controller=\(isController)&publicKey=\(publicKey)&relay=\(relay.asPercentEncodedString())"
    }
}

struct RelayProtocolOptions: Hashable, Codable, Equatable {
    let `protocol`: String
    let params: [String]?
}

extension RelayProtocolOptions {

    func asPercentEncodedString() -> String {
        guard let string = try? self.json().addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
            return ""
        }
        return string ?? ""
    }
}

enum DataConversionError: Error {
    case stringToDataFailed
    case dataToStringFailed
}

extension Encodable {
    func json() throws -> String {
        let data = try JSONEncoder().encode(self)
        guard let string = String(data: data, encoding: .utf8) else {
            throw DataConversionError.dataToStringFailed
        }
        return string
    }
}
