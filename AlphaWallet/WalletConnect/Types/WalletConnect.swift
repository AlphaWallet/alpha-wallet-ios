//
//  WalletConnect.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.11.2021.
//

import Foundation
import WalletConnectSwift
import AlphaWalletFoundation

typealias WalletConnectV1Request = WalletConnectSwift.Request

extension AlphaWallet.WalletConnect.Session {
    enum Request: CustomStringConvertible {
        case v1(request: WalletConnectV1Request, server: RPCServer)
        case v2(request: WalletConnectV2Request)

        var server: RPCServer? {
            switch self {
            case .v1(_, let server):
                return server
            case .v2(let request):
                return request.rpcServer
            }
        }

        var source: Analytics.SignMessageRequestSource {
            switch self {
            case .v1:
                return .walletConnect(.v1)
            case .v2:
                return .walletConnect(.v2)
            }
        }

        var method: String {
            switch self {
            case .v1(let request, _):
                return request.method
            case .v2(let request):
                return request.method
            }
        }

        var description: String {
            topicOrUrl.description
        }

        var topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl {
            switch self {
            case .v1(let request, _):
                return .url(url: WalletConnectV1URL(url: request.url))
            case .v2(let request):
                return .topic(string: request.topic)
            }
        }
    }
}

extension AlphaWallet.WalletConnect {

    enum ServerEditingAvailability {
        case disabled
        case enabled
        case notSupporting
    }

    struct Namespace {
        let chains: Set<RPCServer>
        let methods: Set<String>
        let events: Set<String>
    }

    struct Proposal {
        let name: String
        let iconUrl: URL?
        let dappUrl: URL
        let description: String?
        let serverEditing: ServerEditingAvailability
        let requiredNamespaces: [Namespace]
        let optionalNamespaces: [Namespace]

        init(dAppInfo info: WalletConnectSwift.Session.DAppInfo) {
            description = info.peerMeta.description
            name = info.peerMeta.name
            dappUrl = info.peerMeta.url
            iconUrl = info.peerMeta.icons.first
            //NOTE: Keep in mind, changing servers is available in `info.chainId == nil`, only sing server connection
            if let server: RPCServer = info.chainId.flatMap({ .init(chainID: $0) }) {
                serverEditing = .disabled
                self.requiredNamespaces = [.init(chains: [server], methods: [], events: [])]
            } else {
                //Better than always `.main` even when it's not enabled
                self.requiredNamespaces = [.init(chains: [Config().anyEnabledServer()], methods: [], events: [])]
                serverEditing = .enabled
            }
            self.optionalNamespaces = []
        }

    }

    struct AuthRequest {
        let authRequest: WalletConnectAuthRequest
        var domain: String { authRequest.payload.domain }
        var aud: String { authRequest.payload.aud }
        var nonce: String { authRequest.payload.nonce }
        var chainId: String { authRequest.payload.chainId }
        var iat: String { authRequest.payload.iat }
        var statement: String? { authRequest.payload.statement }
    }

    enum TopicOrUrl: Codable, CustomStringConvertible {
        struct TopicOrUrlError: Error {}

        case topic(string: String)
        case url(url: WalletConnectV1URL)

        var description: String {
            switch self {
            case .topic(let topic):
                return topic
            case .url(let url):
                return url.absoluteString
            }
        }

        private enum Keys: CodingKey {
            case topic
            case url
        }

        private static let valueKey = "value"

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Keys.self)
            if let topic = try? container.decode([String: String].self, forKey: .topic), let value = topic[TopicOrUrl.valueKey] {
                self = .topic(string: value)
            } else if let url = try? container.decode([String: WalletConnectV1URL].self, forKey: .url), let value = url[TopicOrUrl.valueKey] {
                self = .url(url: value)
            } else {
                throw TopicOrUrlError()
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Keys.self)
            switch self {
            case .topic(let string):
                try container.encode([TopicOrUrl.valueKey: string], forKey: .topic)
            case .url(let url):
                try container.encode([TopicOrUrl.valueKey: url], forKey: .url)
            }
        }
    }

    struct Dapp {
        let name: String
        let description: String?
        let url: URL
        let icons: [URL]

        init(dAppInfo info: WalletConnectSwift.Session.DAppInfo) {
            name = info.peerMeta.name
            url = info.peerMeta.url
            icons = info.peerMeta.icons
            description = info.peerMeta.description
        }
    }

    enum MultipleServersSelection {
        case enabled
        case disabled
    }

    struct Session: Hashable {
        let topicOrUrl: TopicOrUrl
        let dapp: Dapp
        let multipleServersSelection: MultipleServersSelection
        let namespaces: [String: SessionNamespace]

        var servers: [RPCServer] {
            let chains = Array(namespaces.values.flatMap { $0.accounts.map { $0.blockchain.absoluteString } })
            return chains.compactMap { Eip155UrlCoder.decodeRpc(from: $0) }
        }

        var accounts: [AlphaWallet.Address] {
            let chains = Array(namespaces.values.flatMap { $0.accounts.map { $0.address } })
            return chains.compactMap { AlphaWallet.Address(string: $0) }
        }

        var methods: [String] {
            Array(namespaces.values.first?.methods ?? [])
        }

        var events: [String] {
            Array(namespaces.values.first?.events ?? [])
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(topicOrUrl.description)
        }
    }

    enum ProposalResponse {
        case connect(RPCServer)
        case cancel

        var shouldProceed: Bool {
            switch self {
            case .connect:
                return true
            case .cancel:
                return false
            }
        }

        var server: RPCServer? {
            switch self {
            case .connect(let server):
                return server
            case .cancel:
                return nil
            }
        }
    }

    enum AuthRequestResponse {
        case connect(RPCServer)
        case cancel

        var shouldProceed: Bool {
            switch self {
            case .connect:
                return true
            case .cancel:
                return false
            }
        }

        var server: RPCServer? {
            switch self {
            case .connect(let server):
                return server
            case .cancel:
                return nil
            }
        }
    }
}

extension AlphaWallet.WalletConnect.Session: Equatable {
    static func == (lhs: AlphaWallet.WalletConnect.Session, rhs: AlphaWallet.WalletConnect.Session) -> Bool {
        return lhs.topicOrUrl == rhs.topicOrUrl
    }
}

extension AlphaWallet.WalletConnect.TopicOrUrl {
    static func == (_ lhs: AlphaWallet.WalletConnect.TopicOrUrl, _ rhs: AlphaWallet.WalletConnect.TopicOrUrl) -> Bool {
        switch (lhs, rhs) {
        case (.url(let url1), .url(let url2)):
            return url1.absoluteString == url2.absoluteString
        case (.topic(let str1), .topic(let str2)):
            return str1 == str2
        case (.topic, .url):
            return false
        case (.url, .topic):
            return false
        }
    }
}

extension Requester {
    init(walletConnectSession session: AlphaWallet.WalletConnect.Session, request: AlphaWallet.WalletConnect.Session.Request) {
        self.init(shortName: session.dappName, name: session.dappNameShort, server: request.server, url: session.dappUrl, iconUrl: session.dappIconUrl)
    }
}

extension WalletConnectSwift.Session {

    var topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl {
        return .url(url: WalletConnectV1URL(url: url))
    }

    var requester: DAppRequester {
        return .init(title: dAppInfo.peerMeta.name, url: dAppInfo.peerMeta.url)
    }
}

extension AlphaWallet.WalletConnect.Session {

    var requester: DAppRequester {
        return .init(title: dappName, url: dappUrl)
    }

    var dappName: String {
        return dapp.name.isEmpty ? "--" : dapp.name
    }

    var dappNameShort: String {
        guard let approxDapName = dappName.components(separatedBy: " ").first, approxDapName.nonEmpty else {
            return dappName
        }

        return approxDapName.isEmpty ? "--" : approxDapName
    }

    var dappIconUrl: URL? { dapp.icons.first }

    var dappUrl: URL { dapp.url }
}

extension WalletConnectV1URL {
    init(url: WCURL) {
        self.init(url.absoluteString)!
    }
}
