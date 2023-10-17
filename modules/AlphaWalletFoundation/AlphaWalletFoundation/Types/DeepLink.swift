//
//  DeepLink.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.01.2022.
//

import Foundation
import AlphaWalletShareExtensionCore
import SwiftyJSON

public enum DeepLink {
    static let walletConnectPath = "/wc"
    static let eip681Path = "/ethereum:"
    static let openUrlPath = "/openurl"
    static let walletPath = "/wallet"

    public enum WalletConnectSource {
        case mobileLinking
        case safariExtension
    }

    case eip681(url: URL)
    case walletConnect(url: AlphaWallet.WalletConnect.ConnectionUrl, source: WalletConnectSource)
    case embeddedUrl(server: RPCServer, url: URL)
    case shareContentAction(action: ShareContentAction)
    case magicLink(signedOrder: SignedOrder, server: RPCServer, url: URL)
    case maybeFileUrl(url: URL)
    case walletApi(DeepLink.WalletApi)
    case attestation(url: URL)

    public init?(url: URL, supportedServers: [RPCServer] = [.main]) {
        if url.isFileURL {
            self = .maybeFileUrl(url: url)
        } else if let eip681Url = functional.extractEip681UrlMaybeEmbedded(in: url, supportedServers: supportedServers) {
            self  = .eip681(url: eip681Url)
        } else if let (wcUrl, source) = functional.extractWalletConnectUrlMaybeEmbedded(in: url) {
            self = .walletConnect(url: wcUrl, source: source)
        } else if let (server, url) = functional.extractEmbeddedUrl(in: url, supportedServers: supportedServers) {
            self = .embeddedUrl(server: server, url: url)
        } else if let value = ShareContentAction(url) {
            self = .shareContentAction(action: value)
        } else if let (server, signedOrder) = functional.extractEmbeddedMagicLinkData(url: url) {
            self = .magicLink(signedOrder: signedOrder, server: server, url: url)
        } else if let value = functional.extractEmbeddedWalletApiCall(url: url, supportedServers: []) {
            self = .walletApi(value)
        } else if url.absoluteString.contains("attestation=") || url.absoluteString.contains("ticket=") {
            //TODO we are cheating here. Because AlphaWalletAttestation depends on AlphaWalletFoundation, we can't use the former to decode and verify the URL does include an attestation. Improve this
            self = .attestation(url: url)
        } else {
            return nil
        }
    }

    public static func supports(url: URL) -> Bool {
        return DeepLink(url: url) != nil
    }
}

extension DeepLink {
    public enum functional {}
}

extension DeepLink {
    public enum WalletApi {
        case signPersonalMessage(address: AlphaWallet.Address?, server: RPCServer, redirectUrl: URL, version: String, metadata: Metadata, message: String)
        case connect(redirectUrl: URL, version: String, metadata: Metadata)

        public enum Action: String {
            case signPersonalMessage = "signpersonalmessage"
            case connect = "connect"

            init?(string: String) {
                self.init(rawValue: string.lowercased())
            }
        }

        public enum Params {
            static let redirectUrl = "redirecturl"
            static let metadata = "metadata"
            static let message = "message"
            static let address = "address"
        }
    }

    public struct Metadata {
        public let name: String
        public let iconUrl: URL?
        public let appUrl: URL?

        public init?(json: JSON) {
            guard let name = json["name"].string else { return nil }

            self.name = name
            self.iconUrl = json["iconurl"].string.flatMap { URL(string: $0) }
            self.appUrl = json["appurl"].string.flatMap { URL(string: $0) }
        }
    }
}

//internal instead of fileprivate to expose to tests
extension DeepLink.functional {
    //E.g. https://aw.app/wallet/v1/connect?redirecturl=https%3A%2F%2Fmyapp.com&metadata=%7B%22name%22%3A%22Some%20app%22%2C%22iconurl%22%3A%22https%3A%2F%2Fimg.icons8.com%2Fnolan%2F344%2Fethereum.png%22%2C%20%22appurl%22%3A%20%22https%3A%2F%2Funiswap.org%2F%22%2C%20%22note%22%3A%22This%20will%20inform%20them%20your%20wallet%20address%20is%200x2322%E2%80%A62324%22%7D
    //E.g https://aw.app/wallet/v1/signpersonalmessage?redirecturl=https%3A%2F%2Fmyapp.com%3Fparam_1%3Dnope%26param_2%3D34&metadata=%7B%22name%22%3A%22Some%20app%22%2C%22iconurl%22%3A%22https%3A%2F%2Fimg.icons8.com%2Fnolan%2F344%2Fethereum.png%22%2C%20%22appurl%22%3A%20%22https%3A%2F%2Funiswap.org%2F%22%2C%20%22note%22%3A%22This%20will%20inform%20them%20your%20wallet%20address%20is%200x2322%E2%80%A62324%22%7D&message=0x48656c6c6f20416c7068612057616c6c6574

    static func extractEmbeddedWalletApiCall(url: URL, supportedServers: [RPCServer]) -> DeepLink.WalletApi? {
        guard let result = extractSupportingServerAndPath(url: url, supportedServers: supportedServers, path: DeepLink.walletPath) else {
            return nil
        }

        guard let decodedPath = result.path.replacingPlusWithPercent20 else { return nil }
        guard let components = URLComponents(string: decodedPath) else { return nil }
        let queryItems = components.queryItemsDictionary
        let pathComponents = components.path.components(separatedBy: "/")

        guard pathComponents.count >= 3 else { return nil }

        let version = pathComponents[1]
        switch DeepLink.WalletApi.Action(string: pathComponents[2]) {
        case .connect:
            guard let redirectUrl = components.queryItemsDictionary[DeepLink.WalletApi.Params.redirectUrl].flatMap({ URL(string: $0) }) else { return nil }

            guard let json = queryItems[DeepLink.WalletApi.Params.metadata]
                .flatMap({ $0.data(using: .utf8) })
                .flatMap({ try? JSON(data: $0) }) else { return nil }

            guard let metadata = DeepLink.Metadata(json: json) else { return nil }

            return .connect(redirectUrl: redirectUrl, version: version, metadata: metadata)
        case .signPersonalMessage:
            guard let redirectUrl = queryItems[DeepLink.WalletApi.Params.redirectUrl].flatMap({ URL(string: $0) }) else { return nil }

            guard let json = queryItems[DeepLink.WalletApi.Params.metadata]
                .flatMap({ $0.data(using: .utf8) })
                .flatMap({ try? JSON(data: $0) }) else { return nil }

            guard let metadata = DeepLink.Metadata(json: json) else { return nil }
            guard let message = queryItems[DeepLink.WalletApi.Params.message] else { return nil }
            let address = components.queryItemsDictionary[DeepLink.WalletApi.Params.address].flatMap({ AlphaWallet.Address(string: $0) })

            return .signPersonalMessage(address: address, server: result.server, redirectUrl: redirectUrl, version: version, metadata: metadata, message: message)
        case .none:
            return nil
        }
    }

    static func extractEmbeddedMagicLinkData(url: URL) -> (server: RPCServer, signedOrder: SignedOrder)? {
        guard let server = RPCServer(withMagicLink: url) else { return nil }
        let isLegacyLink = url.description.hasPrefix(Constants.legacyMagicLinkPrefix)
        let prefix: String
        if isLegacyLink {
            prefix = Constants.legacyMagicLinkPrefix
        } else {
            prefix = server.magicLinkPrefix.description
        }
        guard let signedOrder = UniversalLinkHandler(server: server).parseUniversalLink(url: url.absoluteString, prefix: prefix) else {
            return nil
        }

        return (server: server, signedOrder: signedOrder)
    }

    static func extractSupportingServerAndPath(url: URL, supportedServers: [RPCServer], path: String) -> (path: String, server: RPCServer)? {
        guard let magicLinkServer = RPCServer(withMagicLink: url), url.path.starts(with: path) else { return nil }
        let eip681Url = url.absoluteString.replacingOccurrences(of: magicLinkServer.magicLinkPrefix.absoluteString, with: "")
        return (eip681Url, magicLinkServer)
    }

    //E.g. https://aw.app/ethereum:0x89205a3a3b2a69de6dbf7f01ed13b2108b2c43e7/transfer?address=0x8e23ee67d1332ad560396262c48ffbb01f93d052&uint256=1
    static func extractEip681UrlMaybeEmbedded(in url: URL, supportedServers: [RPCServer]) -> URL? {
        let rawEip681Url: URL? = {
            guard let scheme = url.scheme, scheme == Eip681Parser.scheme, AddressOrEip681Parser.from(string: url.absoluteString) != nil else { return nil }
            switch AddressOrEip681Parser.from(string: url.absoluteString) {
            case .none, .address:
                return nil
            case .eip681:
                return url
            }
        }()

        let eip681Url: URL? = {
            guard let result = extractSupportingServerAndPath(url: url, supportedServers: supportedServers, path: DeepLink.eip681Path) else {
                return nil
            }
            let eip681Url = result.path
            switch AddressOrEip681Parser.from(string: eip681Url) {
            case .address, .none:
                return nil
            case .eip681:
                return URL(string: eip681Url)
            }
        }()

        return rawEip681Url ?? eip681Url
    }

    static func extractEmbeddedUrl(in url: URL, supportedServers: [RPCServer]) -> (RPCServer, URL)? {
        guard let result = extractSupportingServerAndPath(url: url, supportedServers: supportedServers, path: DeepLink.openUrlPath) else {
            return nil
        }

        guard let components = URLComponents(string: result.path) else { return nil }
        let queryItems = components.queryItems ?? []
        guard let urlToOpen = queryItems.first(where: { $0.name == "url" })?.value.flatMap({ URL(string: $0) }) else { return nil }

        return (result.server, urlToOpen)
    }

    //Multiple formats:
    //From WalletConnect mobile linking: e.g. https://aw.app/wc?uri=wc%3A588422fd-929d-438a-b337-31c3c9184d9b%401%3Fbridge%3Dhttps%253A%252F%252Fbridge.walletconnect.org%26key%3D8f9459f72aed0790282c47fe45f37ed5cb121bc17795f8f2a229a910bc447202
    //From AlphaWallet iOS Safari extension's rewriting: eg. https://aw.app/wc:f607884e-63a5-4fa3-8e7d-af6f6fa9b51f@1?bridge=https%3A%2F%2Fn.bridge.walletconnect.org&key=cff9abba23cb9f843e9d623b891a5f8948b41f7d4afc7f7155aa252504cd8264

    //awallet://wc?uri=wc%3A5f577f99-2f54-40f7-9463-7ff640772090%401%3Fbridge%3Dhttps%253A%252F%252Fwalletconnect.depay.com%26key%3D1938aa2c9d4104c91cbc60e94631cf769c96ebad1ea2fc30e18ba09e39bc3c0b
    static func extractWalletConnectUrlMaybeEmbedded(in url: URL) -> (url: AlphaWallet.WalletConnect.ConnectionUrl, source: DeepLink.WalletConnectSource)? {
        if url.scheme == "wc", let wcUrl = AlphaWallet.WalletConnect.ConnectionUrl(url.absoluteString) {
            return (wcUrl, .mobileLinking)
        } else if url.path.starts(with: DeepLink.walletConnectPath) {
            if let url = extractWalletConnectUrlFromSafariExtensionRewrittenUrl(url) {
                return (url, .safariExtension)
            } else if let url = extractWalletConnectUrlFromWalletConnectMobileLinking(url) {
                return (url, .mobileLinking)
            } else {
                return nil
            }
        } else if url.host == "wc", let url = extractWalletConnectUrlFromWalletConnectMobileLinking(url) {
            return (url, .mobileLinking)
        } else {
            return nil
        }
    }

    static func extractWalletConnectUrlFromSafariExtensionRewrittenUrl(_ url: URL) -> AlphaWallet.WalletConnect.ConnectionUrl? {
        guard let magicLinkServer = RPCServer(withMagicLink: url) else { return nil }
        let _url: URL? = url
        let wcUrl = _url
            .flatMap({ $0.absoluteString })
            .flatMap({ $0.replacingOccurrences(of: magicLinkServer.magicLinkPrefix.absoluteString, with: "") })
            .flatMap({ AlphaWallet.WalletConnect.ConnectionUrl($0) })

        return wcUrl
    }

    static func extractWalletConnectUrlFromWalletConnectMobileLinking(_ url: URL) -> AlphaWallet.WalletConnect.ConnectionUrl? {
        //NOTE: URLComponents is clearer solution, but for some reasons it doesn't resolve all parameters from url
        let scheme = RPCServer(withMagicLink: url)?.magicLinkPrefix.absoluteString ?? "\(url.scheme)://"

        let _url: URL? = url
        let wcUrl1 = _url
            .flatMap({ $0.absoluteString })
            .flatMap({ $0.replacingOccurrences(of: scheme, with: "") })
            .flatMap({ $0.replacingOccurrences(of: "wc?uri=", with: "") })
            .flatMap({ AlphaWallet.WalletConnect.ConnectionUrl($0) })

        let wcUrl2 = _url
            .flatMap({ URLComponents(url: $0, resolvingAgainstBaseURL: true)?.queryItems })
            .flatMap({ $0.first(where: { $0.name == "uri" })?.value })
            .flatMap({ AlphaWallet.WalletConnect.ConnectionUrl($0) })

        return wcUrl1 ?? wcUrl2
        //no-op. According to WalletConnect docs, this is just to get iOS to switch over to the app for signing, etc. e.g. https://aw.app/wc?uri=wc:00e46b69-d0cc-4b3e-b6a2-cee442f97188@1
    }
}

extension URLComponents {
    var queryItemsDictionary: [String: String] {
        get {
            var params: [String: String] = [:]
            return queryItems?.reduce([:], { (_, item) -> [String: String] in
                params[item.name] = item.value
                return params
            }) ?? [:]
        }
        set {
            queryItems = newValue.map { URLQueryItem(name: $0, value: "\($1)") }
        }
    }
}

extension String {

    var replacingPlusWithPercent20: String? {
        let unreserved = "*-._"
        let allowed = NSMutableCharacterSet.alphanumeric()
        allowed.addCharacters(in: unreserved)
        allowed.addCharacters(in: "+")

        var encoded = addingPercentEncoding(withAllowedCharacters: allowed as CharacterSet)
        encoded = encoded?.replacingOccurrences(of: "+", with: "%20")

        return encoded?.removingPercentEncoding?.replacingOccurrences(of: " ", with: "%20")
    }
}
