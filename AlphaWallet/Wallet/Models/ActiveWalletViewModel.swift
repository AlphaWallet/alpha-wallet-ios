// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

struct ActiveWalletViewModel {
    let initialTab: Tabs = .tokens
}

extension ActiveWalletViewModel {
    enum Error: LocalizedError {
        //TODO rename or move
        case onlyWatchAccount

        var errorDescription: String? {
            return R.string.localizable.inCoordinatorErrorOnlyWatchAccount()
        }
    }

    enum Tabs {
        case tokens
        case settings
        case transactions
        case activities
        case browser
        case swap

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
                return String(describing: BrowserHomeViewController.self)
            case .swap:
                return String(describing: UIViewController.self)
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
            case .swap:
                let tabBarItem = UITabBarItem(title: nil, image: nil, selectedImage: nil)
                tabBarItem.imageInsets = .init(top: 7, left: 0, bottom: -7, right: 0)
                tabBarItem.isEnabled = false

                return tabBarItem
            }
        }
    }
}
