//
//  UniversalLinkService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.11.2020.
//

import UIKit

public enum UrlSource {
    case deeplink
    case customUrlScheme
    case dappBrowser
    case others
}

public protocol UniversalLinkServiceDelegate: AnyObject {
    func handle(url: DeepLink)
    func canHandleUniversalLink(for coordinator: UniversalLinkService) -> Bool
}

open class UniversalLinkService {
    private var pendingUniversalLinkUrl: DeepLink? = .none
    private let analytics: AnalyticsLogger

    open weak var delegate: UniversalLinkServiceDelegate?

    public init(analytics: AnalyticsLogger) {
        self.analytics = analytics
    }

    open func handleUniversalLinkInPasteboard() {
        let universalLinkPasteboard = UniversalLinkInPasteboardService()
        universalLinkPasteboard.delegate = self
        universalLinkPasteboard.start()
    }

    @discardableResult open func handleUniversalLink(url: URL, source: UrlSource) -> Bool {
        if let universalLink = DeepLink(url: url) {
            logDeeplinkUsage(source: source, universalLink: universalLink, url: url)

            if let canHandle = delegate?.canHandleUniversalLink(for: self), canHandle {
                handle(url: universalLink)
            } else {
                pendingUniversalLinkUrl = universalLink
            }

            return true
        } else {
            return false
        }
    }

    open func handlePendingUniversalLink() {
        guard let url = pendingUniversalLinkUrl else { return }

        handle(url: url)
    }

    private func handle(url: DeepLink) {
        delegate?.handle(url: url)

        pendingUniversalLinkUrl = .none
    }
}

extension UniversalLinkService: UniversalLinkInPasteboardServiceDelegate {
    public func importUniversalLink(url: DeepLink, for service: UniversalLinkInPasteboardService) {
        if let canHandle = delegate?.canHandleUniversalLink(for: self), canHandle {
            self.handle(url: url)
        } else {
            pendingUniversalLinkUrl = url
        }
    }
}

// MARK: Analytics
extension UniversalLinkService {
    private func logDeeplinkUsage(source: UrlSource, universalLink: DeepLink, url: URL) {
        switch source {
        case .deeplink:
            switch universalLink {
            case .eip681:
                analytics.log(action: Analytics.Action.deeplinkVisited, properties: [
                    Analytics.Properties.type.rawValue: Analytics.EmbeddedDeepLinkType.eip681.rawValue
                ])
            case .walletConnect:
                analytics.log(action: Analytics.Action.deeplinkVisited, properties: [
                    Analytics.Properties.type.rawValue: Analytics.EmbeddedDeepLinkType.walletConnect.rawValue
                ])
            case .embeddedUrl:
                analytics.log(action: Analytics.Action.deeplinkVisited, properties: [
                    Analytics.Properties.type.rawValue: Analytics.EmbeddedDeepLinkType.others.rawValue
                ])
            case .walletApi(let type):
                let type: String = {
                    switch type {
                    case .connect:
                        return "connect"
                    case .signPersonalMessage:
                        return "signPersonalMessage"
                    }
                }()
                analytics.log(action: Analytics.Action.deepLinkWalletApiCall, properties: [
                    Analytics.Properties.type.rawValue: type
                ])
            case .shareContentAction, .magicLink, .maybeFileUrl:
                break
            }
        case .customUrlScheme:
            analytics.log(action: Analytics.Action.customUrlSchemeVisited, properties: [
                //Custom URL scheme should actually be extracted from the `DeepLink`, but since it's a custom URL scheme the original `url` shouldn't be a deeplink embedding it, so it's a shortcut
                Analytics.Properties.scheme.rawValue: url.scheme ?? ""
            ])
        case .dappBrowser, .others:
            break
        }
    }
}
