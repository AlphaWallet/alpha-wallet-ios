//
//  PriceAlertsPageViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import UIKit

struct PriceAlertsPageViewModel {
    var title: String { return "Alerts" }

    var backgroundColor: UIColor = Colors.appWhite
    var emptyAlertListTitle: String = "Alerts will appear here"
    var alerts: [PriceAlert]

    var addNewAlertViewModel: ShowAddHideTokensViewModel {
        return .init(addHideTokensIcon: R.image.add_hide_tokens(), addHideTokensTitle: "Add New Price Alert", backgroundColor: R.color.alabaster()!, badgeText: nil)
    }

    mutating func removeAlert(indexPath: IndexPath) {
        alerts.remove(at: indexPath.row)
    }
}
