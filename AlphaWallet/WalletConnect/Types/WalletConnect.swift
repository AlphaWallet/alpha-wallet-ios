//
//  WalletConnect.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.11.2021.
//

import Foundation
import WalletConnectSwift 

typealias WalletConnectV1Request = WalletConnectSwift.Request
protocol SessionIdentifiable {
    var identifier: AlphaWallet.WalletConnect.SessionIdentifier { get }
}

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

        var method: String {
            switch self {
            case .v1(let request, _):
                return request.method
            case .v2(let request):
                return request.method
            }
        }

        var description: String {
            sessionId.description
        }

        var sessionId: AlphaWallet.WalletConnect.SessionIdentifier {
            switch self {
            case .v1(let request, _):
                return .url(url: request.url)
            case .v2(let request):
                return .topic(string: request.topic)
            }
        }
    }
}

extension AlphaWallet {
    
    enum WalletConnect {

        enum ConnectionUrl: Codable {
            case v1(wcUrl: WalletConnectV1URL)
            case v2(uri: WalletConnectV2URI)

            struct ConnectionUrlError: Error {}

            private enum Keys: CodingKey {
                case url
                case uri
            }
            
            var absoluteString: String {
                switch self {
                case .v1(let wcUrl):
                    return wcUrl.absoluteString
                case .v2(let uri):
                    return uri.absoluteString
                }
            }

            init?(_ string: String) {
                if let v2 = WalletConnectV2URI(string: string) {
                    self = .v2(uri: v2)
                } else if let v1 = WalletConnectV1URL(string) {
                    self = .v1(wcUrl: v1)
                } else {
                    return nil
                }
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: Keys.self)
                if let rawValue = try? container.decode(String.self, forKey: .url), let value = ConnectionUrl(rawValue) {
                    self = value
                } else {
                    throw ConnectionUrlError()
                }
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: Keys.self)
                try container.encode(absoluteString, forKey: .url)
            }
        }

        struct SessionProposal {
            let name: String
            let iconUrl: URL?
            let servers: [RPCServer]
            let dappUrl: URL
            let description: String?
            let methods: [String]
            let isServerEditingAvailable: Bool?
            var isV1SessionProposal: Bool {
                return isServerEditingAvailable != nil
            }

            init(dAppInfo info: WalletConnectSwift.Session.DAppInfo, url: WalletConnectV1URL) {
                description = info.peerMeta.description
                name = info.peerMeta.name
                dappUrl = info.peerMeta.url
                iconUrl = info.peerMeta.icons.first
                //NOTE: Keep in mind, changing servers is available in `info.chainId == nil`, only sing server connection
                if let server: RPCServer = info.chainId.flatMap({ .init(chainID: $0) }) {
                    isServerEditingAvailable = false
                    servers = [server]
                } else {
                    servers = [.main]
                    isServerEditingAvailable = true
                }
                methods = []
            }
            
        }

        enum SessionIdentifier: Codable, CustomStringConvertible {
            struct SessionIdentifierError: Error {}

            case topic(string: String)
            case url(url: WalletConnectV1URL)
            
            var description: String {
                switch self {
                case .topic(let string):
                    return string
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
                if let topic = try? container.decode([String: String].self, forKey: .topic), let value = topic[SessionIdentifier.valueKey] {
                    self = .topic(string: value)
                } else if let url = try? container.decode([String: WalletConnectV1URL].self, forKey: .url), let value = url[SessionIdentifier.valueKey] {
                    self = .url(url: value)
                } else {
                    throw SessionIdentifierError()
                }
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: Keys.self)
                switch self {
                case .topic(let string):
                    try container.encode([SessionIdentifier.valueKey: string], forKey: .topic)
                case .url(let url):
                    try container.encode([SessionIdentifier.valueKey: url], forKey: .url)
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

        struct Session: Equatable {
            static func == (lhs: AlphaWallet.WalletConnect.Session, rhs: AlphaWallet.WalletConnect.Session) -> Bool {
                return lhs.identifier == rhs.identifier
            }

            let identifier: SessionIdentifier
            var servers: [RPCServer]
            let dapp: Dapp
            var methods: [String]
            let isMultipleServersEnabled: Bool 
        }

        enum SessionProposalResponse {
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
}

///WalletConnect SDK connection URL
typealias WalletConnectV1URL = WalletConnectSwift.WCURL

///NFDSession - Non Full Disconnectable Session - when the session have a multiple connected servers we able to update this session with excluding non needed servers
///- serversToDisconnect - servers we are going to disconnect, `session.servers.filter{ !serversToDisconnect.contains($0) }`  its gonna to be servers that we want to left connected
///- session - session instance
typealias NFDSession = (session: AlphaWallet.WalletConnect.Session, serversToDisconnect: [RPCServer])

enum SessionsToDisconnect {
    case allExcept(_ servers: [RPCServer])
    case all
}

extension AlphaWallet.WalletConnect.SessionIdentifier {
    static func == (_ lhs: AlphaWallet.WalletConnect.SessionIdentifier, _ rhs: AlphaWallet.WalletConnect.SessionIdentifier) -> Bool {
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

struct WalletConnectDappRequesterViewModel {
    let dappShortName: String
    let dappName: String
    let server: RPCServer
    let dappUrl: URL
    let dappIconUrl: URL?

    init(walletConnectSession session: AlphaWallet.WalletConnect.Session, request: AlphaWallet.WalletConnect.Session.Request) {
        dappName = session.dappName
        dappShortName = session.dappNameShort
        dappUrl = session.dappUrl
        //NOTE: actually it should always have a value
        server = request.server!
        dappIconUrl = session.dappIconUrl
    }
}

extension WalletConnectSwift.Session: SessionIdentifiable {

    var identifier: AlphaWallet.WalletConnect.SessionIdentifier {
        return .url(url: url)
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
        return dapp.name
    }

    var dappNameShort: String {
        guard let approxDapName = dappName.components(separatedBy: " ").first, approxDapName.nonEmpty else {
            return dappName
        }

        return approxDapName
    }

    var dappIconUrl: URL? {
        dapp.icons.first
    }

    var dappUrl: URL {
        dapp.url
    }
}
