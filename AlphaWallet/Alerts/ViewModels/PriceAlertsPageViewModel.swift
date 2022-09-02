//
//  PriceAlertsPageViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import UIKit
import AlphaWalletFoundation

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

extension AlertType {
    var icon: UIImage? {
        switch self {
        case .price(let priceTarget, _):
            switch priceTarget {
            case .above:
                return R.image.iconsSystemUp()
            case .below:
                return R.image.iconsSystemDown()
            }
        }
    }

    var title: String {
        switch self {
        case .price(let priceTarget, let value):
            let result = Formatter.fiat.string(from: value) ?? "-"
            return "\(priceTarget.title) \(result)"
        }
    }
}

extension PriceAlert {
    var description: String { return type.title }
    var icon: UIImage? { return type.icon }
    var title: String { return type.title }
}

extension PriceTarget {
    var title: String {
        switch self {
        case .above: return R.string.localizable.priceAlertAbove()
        case .below: return R.string.localizable.priceAlertBelow()
        }
    }
}

