//
//  BuyCryptoUsingThirdPartyCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.08.2022.
//

import UIKit
import AlphaWalletFoundation

protocol BuyCryptoUsingThirdPartyCoordinatorDelegate: AnyObject {
    func openUrlInBrowser(url: URL, animated: Bool)
}

class BuyCryptoUsingThirdPartyCoordinator: Coordinator {
    private let service: BuyTokenURLProviderType & SupportedTokenActionsProvider
    private let token: TokenActionsIdentifiable
    private let source: Analytics.BuyCryptoSource
    private let analytics: AnalyticsLogger

    var coordinators: [Coordinator] = []
    weak var delegate: BuyCryptoUsingThirdPartyCoordinatorDelegate?

    init(service: BuyTokenURLProviderType & SupportedTokenActionsProvider,
         token: TokenActionsIdentifiable,
         source: Analytics.BuyCryptoSource,
         analytics: AnalyticsLogger) {

        self.service = service
        self.token = token
        self.source = source
        self.analytics = analytics
    }

    func start(wallet: Wallet) {
        if let url = service.url(token: token, wallet: wallet) {
            analytics.log(navigation: service.analyticsNavigation, properties: [
                Analytics.Properties.name.rawValue: service.analyticsName,
                Analytics.Properties.source.rawValue: source.rawValue
            ])

            delegate?.openUrlInBrowser(url: url, animated: true)
        } else {
            let fallbackUrl = URL(string: "https://alphawallet.com/browser-item-category/utilities/")!

            delegate?.openUrlInBrowser(url: fallbackUrl, animated: true)
        }
    }
}
