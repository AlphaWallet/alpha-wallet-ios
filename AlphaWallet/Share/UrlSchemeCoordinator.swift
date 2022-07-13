//
//  UniversalLinkService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.11.2020.
//

import UIKit

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

    weak var delegate: UniversalLinkServiceDelegate?

    func handleUniversalLinkInPasteboard() {
        let universalLinkPasteboardCoordinator = UniversalLinkInPasteboardCoordinator()
        universalLinkPasteboardCoordinator.delegate = self
        universalLinkPasteboardCoordinator.start()
    }

    @discardableResult func handleUniversalLink(url: URL) -> Bool {
        if let universalLink = DeepLink(url: url) {
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
