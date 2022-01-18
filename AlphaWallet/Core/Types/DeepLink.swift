//
//  DeepLink.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.01.2022.
//

import Foundation

enum DeepLink {
    static let walletConnectPath = "/wc"
    static let eip681Path = "/ethereum:"
    static let openUrlPath = "/openurl"

    enum WalletConnectSource {
        case mobileLinking
        case safariExtension
    }

    case eip681(url: URL)
    case walletConnect(url: AlphaWallet.WalletConnect.ConnectionUrl, source: WalletConnectSource)
    case embeddedUrl(server: RPCServer, url: URL)
    case shareContentAction(action: ShareContentAction)
    case magicLink(signedOrder: SignedOrder, server: RPCServer, url: URL)
    case maybeFileUrl(url: URL)

    init?(url: URL, supportedServers: [RPCServer] = [.main]) {
        if url.isFileURL {
            self = .maybeFileUrl(url: url)
        } else if let eip681Url = Self.functional.hasEip681Path(in: url, supportedServers: supportedServers) {
            self  = .eip681(url: eip681Url)
        } else if let (wcUrl, source) = Self.functional.hasWalletConnectPath(in: url) {
            self = .walletConnect(url: wcUrl, source: source)
        } else if let (server, url) = Self.functional.hasEmbeddedUrlPath(in: url, supportedServers: supportedServers) {
            self = .embeddedUrl(server: server, url: url)
        } else if let value = ShareContentAction(url) {
            self = .shareContentAction(action: value)
        } else if let (server, signedOrder) = Self.functional.hasMagicLink(url: url) {
            self = .magicLink(signedOrder: signedOrder, server: server, url: url)
        } else {
            return nil
        }
    }

    static func supports(url: URL) -> Bool {
        return DeepLink(url: url) != nil
    }
}

extension DeepLink {
    class functional {}
}

extension DeepLink.functional {

    static func hasMagicLink(url: URL) -> (server: RPCServer, signedOrder: SignedOrder)? {
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

    private static func validateSupportingServerAndPath(url: URL, supportedServers: [RPCServer], path: String) -> (path: String, server: RPCServer)? {
        func isServerSupported(server: RPCServer) -> Bool {
            guard !supportedServers.isEmpty else { return true }
            return supportedServers.contains(server)
        }

        guard let magicLinkServer = RPCServer(withMagicLink: url), url.path.starts(with: path) else { return nil }
        let eip681Url = url.absoluteString.replacingOccurrences(of: magicLinkServer.magicLinkPrefix.absoluteString, with: "")
        return (eip681Url, magicLinkServer)
    }

    //E.g. https://aw.app/ethereum:0x89205a3a3b2a69de6dbf7f01ed13b2108b2c43e7/transfer?address=0x8e23ee67d1332ad560396262c48ffbb01f93d052&uint256=1
    static func hasEip681Path(in url: URL, supportedServers: [RPCServer]) -> URL? {
        let rawEip681Url: URL? = {
            guard let scheme = url.scheme, scheme == Eip681Parser.scheme, QRCodeValueParser.from(string: url.absoluteString) != nil else { return nil }
            switch QRCodeValueParser.from(string: url.absoluteString) {
            case .none, .address:
                return nil
            case .eip681:
                return url
            }
        }()

        let eip681Url: URL? = {
            guard let result = validateSupportingServerAndPath(url: url, supportedServers: supportedServers, path: DeepLink.eip681Path) else {
                return nil
            }
            let eip681Url = result.path
            switch QRCodeValueParser.from(string: eip681Url) {
            case .address, .none:
                return nil
            case .eip681:
                return URL(string: eip681Url)
            }
        }()

        return rawEip681Url ?? eip681Url
    }

    static func hasEmbeddedUrlPath(in url: URL, supportedServers: [RPCServer]) -> (RPCServer, URL)? {
        guard let result = validateSupportingServerAndPath(url: url, supportedServers: supportedServers, path: DeepLink.openUrlPath) else {
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
    static func hasWalletConnectPath(in url: URL) -> (url: AlphaWallet.WalletConnect.ConnectionUrl, source: DeepLink.WalletConnectSource)? {
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
        } else {
            return nil
        }
    }

    private static func extractWalletConnectUrlFromSafariExtensionRewrittenUrl(_ url: URL) -> AlphaWallet.WalletConnect.ConnectionUrl? {
        guard let magicLinkServer = RPCServer(withMagicLink: url) else { return nil }
        let _url: URL? = url
        let wcUrl = _url
            .flatMap({ $0.absoluteString })
            .flatMap({ $0.replacingOccurrences(of: magicLinkServer.magicLinkPrefix.absoluteString, with: "") })
            .flatMap({ AlphaWallet.WalletConnect.ConnectionUrl($0) })

        return wcUrl
    }

    private static func extractWalletConnectUrlFromWalletConnectMobileLinking(_ url: URL) -> AlphaWallet.WalletConnect.ConnectionUrl? {
        //NOTE: URLComponents is clearer solution, but for some reasons it doesn't resolve all parameters from url
        guard let magicLinkServer = RPCServer(withMagicLink: url) else { return nil }
        let _url: URL? = url
        let wcUrl1 = _url
            .flatMap({ $0.absoluteString })
            .flatMap({ $0.replacingOccurrences(of: magicLinkServer.magicLinkPrefix.absoluteString, with: "") })
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
