//
//  BuyCryptoUsingThirdPartyCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.08.2022.
//

import UIKit
import AlphaWalletFoundation

protocol BuyCryptoUsingThirdPartyCoordinatorDelegate: AnyObject, CanOpenURL {
}

class BuyCryptoUsingThirdPartyCoordinator: Coordinator {
    private let service: BuyTokenURLProviderType & SupportedTokenActionsProvider
    private let token: TokenActionsIdentifiable
    private let viewController: UIViewController
    private let source: Analytics.BuyCryptoSource
    private let analytics: AnalyticsLogger

    var coordinators: [Coordinator] = []
    weak var delegate: BuyCryptoUsingThirdPartyCoordinatorDelegate?

    init(service: BuyTokenURLProviderType & SupportedTokenActionsProvider, token: TokenActionsIdentifiable, viewController: UIViewController, source: Analytics.BuyCryptoSource, analytics: AnalyticsLogger) {
        self.service = service
        self.token = token
        self.viewController = viewController
        self.source = source
        self.analytics = analytics
    }

    func start(wallet: Wallet) {
        if let url = service.url(token: token, wallet: wallet) {
            analytics.log(navigation: service.analyticsNavigation, properties: [
                Analytics.Properties.name.rawValue: service.analyticsName,
                Analytics.Properties.source.rawValue: source.rawValue
            ])

            delegate?.didPressOpenWebPage(url, in: viewController)
        } else {
            let fallbackUrl = URL(string: "https://alphawallet.com/browser-item-category/utilities/")!
            delegate?.didPressOpenWebPage(fallbackUrl, in: viewController)
        }
    }
}
