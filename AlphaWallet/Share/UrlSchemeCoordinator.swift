//
//  UniversalLinkService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.11.2020.
//

import UIKit

enum UrlSource {
    case deeplink
    case customUrlScheme
    case dappBrowser
    case others
}

protocol UrlSchemeResolver: AnyObject {
    var tokensDataStore: TokensDataStore & DetectedContractsProvideble { get }
    var sessions: ServerDictionary<WalletSession> { get }
    var presentationNavigationController: UINavigationController { get }

    func openURLInBrowser(url: URL)
    func openWalletConnectSession(url: AlphaWallet.WalletConnect.ConnectionUrl)
    func showPaymentFlow(for type: PaymentFlow, server: RPCServer, navigationController: UINavigationController)
}

protocol UniversalLinkServiceDelegate: AnyObject {
    func handle(url: DeepLink, for resolver: UrlSchemeResolver)
    func resolve(for coordinator: UniversalLinkService) -> UrlSchemeResolver?
}

class UniversalLinkService {
    private var pendingUniversalLinkUrl: DeepLink? = .none
    private let analyticsCoordinator: AnalyticsCoordinator

    weak var delegate: UniversalLinkServiceDelegate?

    init(analyticsCoordinator: AnalyticsCoordinator) {
        self.analyticsCoordinator = analyticsCoordinator
    }

    func handleUniversalLinkInPasteboard() {
        let universalLinkPasteboardCoordinator = UniversalLinkInPasteboardCoordinator()
        universalLinkPasteboardCoordinator.delegate = self
        universalLinkPasteboardCoordinator.start()
    }

    @discardableResult func handleUniversalLink(url: URL, source: UrlSource) -> Bool {
        if let universalLink = DeepLink(url: url) {
            logDeeplinkUsage(source: source, universalLink: universalLink, url: url)

            if let resolver = delegate?.resolve(for: self) {
                handle(url: universalLink, with: resolver)
            } else {
                pendingUniversalLinkUrl = universalLink
            }

            return true
        } else {
            return false
        }
    }

    func handlePendingUniversalLink(in resolver: UrlSchemeResolver) {
        guard let url = pendingUniversalLinkUrl else { return }

        handle(url: url, with: resolver)
    }

    private func handle(url: DeepLink, with resolver: UrlSchemeResolver) {
        delegate?.handle(url: url, for: resolver)

        pendingUniversalLinkUrl = .none
    }
}

extension UniversalLinkService: UniversalLinkInPasteboardCoordinatorDelegate {
    func importUniversalLink(url: DeepLink, for coordinator: UniversalLinkInPasteboardCoordinator) {
        if let coordinator = delegate?.resolve(for: self) {
            self.handle(url: url, with: coordinator)
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
                analyticsCoordinator.log(action: Analytics.Action.deeplinkVisited, properties: [
                    Analytics.Properties.type.rawValue: Analytics.EmbeddedDeepLinkType.eip681.rawValue
                ])
            case .walletConnect:
                analyticsCoordinator.log(action: Analytics.Action.deeplinkVisited, properties: [
                    Analytics.Properties.type.rawValue: Analytics.EmbeddedDeepLinkType.walletConnect.rawValue
                ])
            case .embeddedUrl:
                analyticsCoordinator.log(action: Analytics.Action.deeplinkVisited, properties: [
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
                analyticsCoordinator.log(action: Analytics.Action.deepLinkWalletApiCall, properties: [
                    Analytics.Properties.type.rawValue: type
                ])
                break
            case .shareContentAction, .magicLink, .maybeFileUrl:
                break
            }
        case .customUrlScheme:
            analyticsCoordinator.log(action: Analytics.Action.customUrlSchemeVisited, properties: [
                //Custom URL scheme should actually be extracted from the `DeepLink`, but since it's a custom URL scheme the original `url` shouldn't be a deeplink embedding it, so it's a shortcut
                Analytics.Properties.scheme.rawValue: url.scheme ?? ""
            ])
        case .dappBrowser, .others:
            break
        }
    }
}