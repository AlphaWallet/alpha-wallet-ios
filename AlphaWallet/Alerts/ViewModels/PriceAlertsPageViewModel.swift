//
//  PriceAlertsPageViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import UIKit

struct PriceAlertsPageViewModel {
    var title: String { return R.string.localizable.priceAlertNavigationTitle() }

    var backgroundColor: UIColor = Colors.appWhite
    var alerts: [PriceAlert]

    init(alerts: [PriceAlert]?) {
        self.alerts = alerts ?? []
    }

    var addNewAlertViewModel: ShowAddHideTokensViewModel {
        return .init(addHideTokensIcon: R.image.add_hide_tokens(), addHideTokensTitle: R.string.localizable.priceAlertNewAlert(), backgroundColor: R.color.alabaster()!, badgeText: nil)
    }

    mutating func removeAlert(indexPath: IndexPath) {
        alerts.remove(at: indexPath.row)
    }
}
