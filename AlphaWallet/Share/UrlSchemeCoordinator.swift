//
//  UniversalLinkCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.11.2020.
//

import Foundation
import BigInt

protocol UrlSchemeResolver: AnyObject {
    var tokensDataStore: TokensDataStore { get }
    var nativeCryptoCurrencyPrices: ServerDictionary<Subscribable<Double>> { get }
    var nativeCryptoCurrencyBalances: ServerDictionary<Subscribable<BigInt>> { get }
    var presentationNavigationController: UINavigationController { get }

    func openURLInBrowser(url: URL)
    func openWalletConnectSession(url: AlphaWallet.WalletConnect.ConnectionUrl)
    func showPaymentFlow(for type: PaymentFlow, server: RPCServer, navigationController: UINavigationController)
} 

protocol UniversalLinkCoordinatorDelegate: AnyObject {
    func handle(url: DeepLink, for resolver: UrlSchemeResolver)
    func resolve(for coordinator: UniversalLinkCoordinator) -> UrlSchemeResolver?
}

protocol UniversalLinkCoordinatorType {
    func handleUniversalLinkOpen(url: URL) -> Bool
    func handlePendingUniversalLink(in coordinator: UrlSchemeResolver)
    func handleUniversalLinkInPasteboard()
}

class UniversalLinkCoordinator: UniversalLinkCoordinatorType {
    private var pendingUniversalUrl: DeepLink? = .none

    weak var delegate: UniversalLinkCoordinatorDelegate?

    func handleUniversalLinkInPasteboard() {
        let universalLinkPasteboardCoordinator = UniversalLinkInPasteboardCoordinator()
        universalLinkPasteboardCoordinator.delegate = self
        universalLinkPasteboardCoordinator.start()
    }

    @discardableResult func handleUniversalLinkOpen(url: URL) -> Bool {
        if let magicLink = DeepLink(url: url) {
            if let coordinator = delegate?.resolve(for: self) {
                handle(url: magicLink, with: coordinator)
            } else {
                pendingUniversalUrl = magicLink
            }

            return true
        } else {
            return false
        }
    }

    func handlePendingUniversalLink(in coordinator: UrlSchemeResolver) {
        guard let url = pendingUniversalUrl else { return }

        handle(url: url, with: coordinator)
    }

    private func handle(url: DeepLink, with coordinator: UrlSchemeResolver) {
        delegate?.handle(url: url, for: coordinator)
        
        pendingUniversalUrl = .none
    }
}

extension UniversalLinkCoordinator: UniversalLinkInPasteboardCoordinatorDelegate {
    func importUniversalLink(url: DeepLink, for coordinator: UniversalLinkInPasteboardCoordinator) {
        if let coordinator = delegate?.resolve(for: self) {
            self.handle(url: url, with: coordinator)
        } else {
            pendingUniversalUrl = url
        }
    }
}
