//
//  Tabs.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.03.2022.
//

import UIKit

extension UITabBarController {
    enum Tabs {
        case tokens
        case settings
        case transactions
        case activities
        case browser

        var className: String {
            switch self {
            case .tokens:
                return String(describing: TokensViewController.self)
            case .transactions:
                return String(describing: TransactionsViewController.self)
            case .activities:
                return String(describing: ActivitiesViewController.self)
            case .settings:
                return String(describing: SettingsViewController.self)
            case .browser:
                return String(describing: DappsHomeViewController.self)
            }
        }

        var tabBarItem: UITabBarItem {
            switch self {
            case .tokens:
                return UITabBarItem(title: R.string.localizable.walletTokensTabbarItemTitle(), image: R.image.tab_wallet(), selectedImage: nil)
            case .settings:
                return UITabBarItem(title: R.string.localizable.aSettingsNavigationTitle(), image: R.image.tab_settings(), selectedImage: nil)
            case .transactions:
                return UITabBarItem(title: R.string.localizable.transactionsTabbarItemTitle(), image: R.image.tab_transactions(), selectedImage: nil)
            case .activities:
                return UITabBarItem(title: R.string.localizable.activityTabbarItemTitle(), image: R.image.tab_transactions(), selectedImage: nil)
            case .browser:
                return UITabBarItem(title: R.string.localizable.browserTabbarItemTitle(), image: R.image.tab_browser(), selectedImage: nil)
            }
        }
    }
}
