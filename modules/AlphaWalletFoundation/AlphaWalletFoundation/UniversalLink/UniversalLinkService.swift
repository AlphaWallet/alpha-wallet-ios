//
//  UniversalLinkService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.11.2020.
//

import UIKit
import Combine
import AlphaWalletLogger

public enum UrlSource {
    case deeplink
    case customUrlScheme
    case dappBrowser
    case others
}

public protocol UniversalLinkNavigatable: AnyObject {
    func showTokenScriptFileImported(filename: String)
    func openWalletConnectSession(url: AlphaWallet.WalletConnect.ConnectionUrl)
    func showPaymentFlow(for type: PaymentFlow, server: RPCServer)
    func showImportMagicLink(session: WalletSession, url: URL)
    func showServerUnavailable(server: RPCServer)
    func showWalletApi(action: DeepLink.WalletApi)
    func openUrlInDappBrowser(url: URL, animated: Bool)
    func importAttestation(url: URL)
}

public final class ApplicationNavigationHandler {
    private let subject: CurrentValueSubject<ApplicationNavigation, Never>

    public var value: ApplicationNavigation {
        return subject.value
    }

    public var publisher: AnyPublisher<ApplicationNavigation, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(subject: CurrentValueSubject<ApplicationNavigation, Never>) {
        self.subject = subject
    }
}

public enum ApplicationNavigation {
    case selectedWallet
    case walletList
    case walletCreation
    case onboarding
}

public protocol UniversalLinkService: AnyObject {
    var navigation: UniversalLinkNavigatable? { get set }

    func handleUniversalLink(url: URL, source: UrlSource) -> Bool
}

public class BaseUniversalLinkService: UniversalLinkService {
    private var pendingUniversalLinkUrl: DeepLink? = .none
    private let analytics: AnalyticsLogger
    private var cancellable = Set<AnyCancellable>()
    private var navigationCancellable = Set<AnyCancellable>()
    private let tokenScriptOverridesFileManager: TokenScriptOverridesFileManager
    private let dependencies: WalletDependenciesProvidable
    private let keystore: Keystore
    private let navigationHandler: ApplicationNavigationHandler
    private var canHandleUniversalLink: Bool {
        return navigationHandler.value == .selectedWallet
    }

    public weak var navigation: UniversalLinkNavigatable?

    public init(analytics: AnalyticsLogger,
                notificationCenter: NotificationCenter = .default,
                tokenScriptOverridesFileManager: TokenScriptOverridesFileManager,
                dependencies: WalletDependenciesProvidable,
                keystore: Keystore,
                navigationHandler: ApplicationNavigationHandler) {

        self.navigationHandler = navigationHandler
        self.keystore = keystore
        self.dependencies = dependencies
        self.tokenScriptOverridesFileManager = tokenScriptOverridesFileManager
        self.analytics = analytics

        notificationCenter.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.handlePendingUniversalLink() }
            .store(in: &cancellable)

        navigationHandler.publisher
            .filter { $0 == .selectedWallet }
            .sink { [weak self] _ in self?.handlePendingUniversalLink() }
            .store(in: &navigationCancellable)
    }

    private func handleUniversalLinkInPasteboard() {
        let universalLinkPasteboard = UniversalLinkInPasteboardService()
        universalLinkPasteboard.delegate = self
        universalLinkPasteboard.start()
    }

    @discardableResult public func handleUniversalLink(url: URL, source: UrlSource) -> Bool {
        if let universalLink = DeepLink(url: url) {
            logDeeplinkUsage(source: source, universalLink: universalLink, url: url)
            if canHandleUniversalLink {
                handle(url: universalLink)
            } else {
                pendingUniversalLinkUrl = universalLink
            }

            return true
        } else {
            return false
        }
    }

    private func handlePendingUniversalLink() {
        guard let url = pendingUniversalLinkUrl else { return }

        handle(url: url)
    }

    private func handle(url: DeepLink) {
        _handle(url: url)

        pendingUniversalLinkUrl = .none
    }

    private func _handle(url: DeepLink) {
        switch url {
        case .maybeFileUrl(let url):
            tokenScriptOverridesFileManager.importTokenScriptOverrides(url: url)
        case .eip681(let url):
            guard let wallet = keystore.currentWallet, let dependency = dependencies.walletDependencies(walletAddress: wallet.address) else { return }

            let paymentFlowResolver = Eip681UrlResolver(
                sessionsProvider: dependency.sessionsProvider,
                missingRPCServerStrategy: .fallbackToAnyMatching)

            paymentFlowResolver.resolve(url: url)
                .sinkAsync(receiveCompletion: { result in
                    guard case .failure(let error) = result else { return }
                    verboseLog("[Eip681UrlResolver] failure to resolve value from: \(url) with error: \(error)")
                }, receiveValue: { result in
                    switch result {
                    case .address:
                        break //Add handling address, maybe same action when scan qr code
                    case .transaction(let transactionType, let token):
                        self.navigation?.showPaymentFlow(for: .send(type: .transaction(transactionType)), server: token.server)
                    }
                })
        case .walletConnect(let url, let source):
            switch source {
            case .safariExtension:
                analytics.log(action: Analytics.Action.tapSafariExtensionRewrittenUrl, properties: [
                    Analytics.Properties.type.rawValue: "walletConnect"
                ])
            case .mobileLinking:
                break
            }
            navigation?.openWalletConnectSession(url: url)
        case .embeddedUrl(_, let url):
            navigation?.openUrlInDappBrowser(url: url, animated: true)
        case .shareContentAction(let action):
            switch action {
            case .string, .openApp:
                break //NOTE: here we can add parsing Addresses from string
            case .url(let url):
                navigation?.openUrlInDappBrowser(url: url, animated: true)
            }
        case .magicLink(_, let server, let url):
            guard let wallet = keystore.currentWallet, let dependency = dependencies.walletDependencies(walletAddress: wallet.address) else { return }

            if let session = dependency.sessionsProvider.session(for: server) {
                navigation?.showImportMagicLink(session: session, url: url)
            } else {
                navigation?.showServerUnavailable(server: server)
            }
        case .walletApi(let action):
            navigation?.showWalletApi(action: action)
        case .attestation(let url):
            navigation?.importAttestation(url: url)
        }
    }
}

extension BaseUniversalLinkService: UniversalLinkInPasteboardServiceDelegate {
    public func importUniversalLink(url: DeepLink, for service: UniversalLinkInPasteboardService) {
        if canHandleUniversalLink {
            self.handle(url: url)
        } else {
            pendingUniversalLinkUrl = url
        }
    }
}

// MARK: Analytics
extension BaseUniversalLinkService {
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
            case .attestation(let url):
                analytics.log(action: Analytics.Action.attestationMagicLink)
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
