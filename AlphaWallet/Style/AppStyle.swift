// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

func applyStyle() {
    UIBarButtonItem.appearance(whenContainedInInstancesOf: [UIDocumentBrowserViewController.self]).tintColor = Colors.appTint
    UIWindow.appearance().tintColor = Colors.appTint
    UINavigationBar.appearance().tintColor = Colors.navigationTitleColor
    UINavigationBar.appearance().setBackgroundImage(UIImage(color: Colors.appBackground), for: .default)
    UINavigationBar.appearance().backIndicatorImage = R.image.backWhite()
    UINavigationBar.appearance().backIndicatorTransitionMaskImage = R.image.backWhite()
    UINavigationBar.appearance().titleTextAttributes = [
        .foregroundColor: Colors.navigationTitleColor,
        .font: Fonts.semibold(size: 20) as Any
    ]

    //We could have set the backBarButtonItem with an empty title for every view controller, but we don't have a place to do it for Eureka view controllers. Using appearance here, while a hack is still more convenient though, since we don't have to do it for every view controller instance
    UIBarButtonItem.appearance().setBackButtonTitlePositionAdjustment(UIOffset(horizontal: -200, vertical: 0), for: .default)
    UIBarButtonItem.appearance().tintColor = Colors.navigationTitleColor
    UIBarButtonItem.appearance(whenContainedInInstancesOf: [UIToolbar.self]).tintColor = Colors.appTint

    UIToolbar.appearance().tintColor = Colors.appTint

    //Background (not needed in iOS 12.1 on simulator)
    UISearchBar.appearance().backgroundColor = Colors.appBackground
    //Cancel button
    UISearchBar.appearance().tintColor = Colors.navigationTitleColor
    //Cursor color
    UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).tintColor = Colors.navigationTitleColor

    UIRefreshControl.appearance().tintColor = Colors.navigationTitleColor

    UISwitch.appearance().onTintColor = Colors.appTint

    BalanceTitleView.appearance().titleTextColor = Colors.navigationTitleColor
    BalanceTitleView.appearance().subTitleTextColor = Colors.navigationTitleColor
}

func applyStyle(viewController: UIViewController) {
	// See use of setBackButtonTitlePositionAdjustment(:for:) above
//    viewController.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
}

struct Colors {
    static let darkBlue = UIColor(hex: "3375BB")
    static let red = UIColor(hex: "f7506c")
    static let veryLightOrange = UIColor(hex: "FFECC9")
    static let lightGray = UIColor.lightGray
    static let gray = UIColor.gray
    static let darkGray = UIColor(hex: "2f2f2f")
    static let black = UIColor(hex: "313849")
    static let lightBlack = UIColor(hex: "313849")
    static let appBackground = UIColor.white
    static let appTint = UIColor(red: 84, green: 193, blue: 227)
    static let navigationTitleColor = UIColor(red: 110, green: 110, blue: 110)
    static let appWhite = UIColor.white
    static let appText = UIColor(red: 47, green: 47, blue: 47)
    static let appSubtitle = UIColor(red: 117, green: 117, blue: 117)
    static let appHighlightGreen = UIColor(red: 117, green: 185, blue: 67)
    static let appActionButtonGreen = UIColor(red: 105, green: 200, blue: 0)
    static let disabledActionButton = UIColor(hex: "d7ebc8")
    static let appActionButtonShadow = UIColor.clear
    static let appGreenContrastBackground = UIColor(red: 86, green: 153, blue: 8)
    static let appLightButtonSeparator = UIColor(red: 255, green: 255, blue: 255, alpha: 0.2)
    static let appRed = UIColor(red: 204, green: 71, blue: 65)
    static let appGrayLabel = UIColor(red: 155, green: 155, blue: 155)
    static let settingsSubtitle = UIColor(red: 141, green: 141, blue: 141)
}

struct StyleLayout {
    static let sideMargin: CGFloat = 15
}

struct Fonts {
    static let labelSize: CGFloat = 18

    static func light(size: CGFloat) -> UIFont? {
        return UIFont(resource: R.font.sourceSansProLight, size: size)
    }
    static func regular(size: CGFloat) -> UIFont? {
        return UIFont(resource: R.font.sourceSansProRegular, size: size)
    }
    static func semibold(size: CGFloat) -> UIFont? {
        return UIFont(resource: R.font.sourceSansProSemibold, size: size)
    }
    static func bold(size: CGFloat) -> UIFont? {
        return UIFont(resource: R.font.sourceSansProBold, size: size)
    }
    static let tableHeader = Fonts.semibold(size: 15)!
}

extension UISegmentedControl {
    func style() {
        setDividerImage(UIImage(color: Colors.appTint), forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default)
        subviews.forEach { $0.tintColor = Colors.appTint }
    }
}

enum Metrics {
    enum CornerRadius {
        static let popups = CGFloat(20)
        static let box = CGFloat(2)
        static let textbox = CGFloat(4)
        static let button = CGFloat(4)
    }

    enum DappsHome {
        enum Icon {
            static let shadowOffset = CGSize(width: 0, height: 0)
            static let shadowOpacity = Float(0.15)
            static let shadowRadius = CGFloat(6)
            static let shadowColor = UIColor.black
        }
    }
}

enum GroupedTable {
    enum Metric {
        static let cellSpacing = CGFloat(5)
        static let cellSeparatorHeight = CGFloat(1)
    }

    enum Color {
        static let title = UIColor(red: 76, green: 76, blue: 76)
        static let background = UIColor(red: 245, green: 245, blue: 245)
        static let cellSeparator = UIColor(red: 233, green: 233, blue: 233)
    }
}

enum DataEntry {
    enum Color {
        static let border = UIColor(red: 194, green: 194, blue: 194)
        static let text = Colors.appText
        static let label = Colors.appGrayLabel
        static let icon = Colors.appTint
        static let secondary = Colors.appGrayLabel
    }

    enum Metric {
        static let borderThickness = CGFloat(0.5)
        static let cornerRadius = Metrics.CornerRadius.textbox
    }

    enum Font {
        static let text = Fonts.regular(size: ScreenChecker().isNarrowScreen ? 14: 18)
        static let label = Fonts.regular(size: 10)
        static let accessory = Fonts.regular(size: 14)
    }
}

enum SegmentBar {
    enum Color {
        static let highlighted = UIColor(red: 35, green: 158, blue: 197)
    }

    enum Font {
        static let text = Fonts.semibold(size: 16)!
    }
}

enum Screen {
    enum Backup {
        static let subtitleFont = Fonts.regular(size: 28)!
        static let subtitleColor = Colors.darkGray
        static let descriptionFont = Fonts.regular(size: 18)!
        static let descriptionColor = Colors.darkGray
    }

    enum Setting {
        enum Font {
            static let title = Fonts.regular(size: 17)!
            static let subtitle = Fonts.regular(size: 12)!
        }
        enum Color {
            static let background = Colors.appBackground
            static let title = Colors.appText
            static let subtitle = Colors.appSubtitle
            static let image = Colors.appTint
        }
    }

    enum TokenCard {
        enum Font {
            static let title: UIFont = {
                if ScreenChecker().isNarrowScreen {
                    return Fonts.regular(size: 22)!
                } else {
                    return Fonts.regular(size: 25)!
                }
            }()
            static let subtitle = Fonts.regular(size: 13)!
            static let blockChainName = Fonts.semibold(size: 12)!
            static let valueChangeLabel = Fonts.regular(size: 11)!
            static let valueChangeValue = Fonts.semibold(size: 15)!
        }

        enum Color {
            static let background = Colors.appBackground
            static let title = Colors.appText
            static let subtitle = Colors.appSubtitle
            static let valueChangeLabel = Colors.appGrayLabel
            static func valueChangeValue(ticker: CoinTicker?) -> UIColor {
                switch EthCurrencyHelper(ticker: ticker).change24h {
                case .appreciate:
                    return Colors.appHighlightGreen
                case .depreciate:
                    return Colors.appRed
                case .none:
                    return Colors.appGrayLabel
                }
            }
            static let blockChainName = Colors.appWhite
        }

        enum Metric {
            static let blockChainTagCornerRadius = CGFloat(7)
            static let blockChainTagHeight = CGFloat(20)
        }
    }
}
