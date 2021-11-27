// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

func applyStyle() {
    UIBarButtonItem.appearance(whenContainedInInstancesOf: [UIDocumentBrowserViewController.self]).tintColor = Colors.navigationButtonTintColor
    UIWindow.appearance().tintColor = Colors.appTint
    // NOTE: Fixes iOS 15 navigation bar black background
    if #available(iOS 15.0, *) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Colors.headerThemeColor
        appearance.setBackIndicatorImage(R.image.backWhite(), transitionMaskImage: R.image.backWhite())
        appearance.shadowImage = UIImage()
        appearance.titleTextAttributes = [
            .foregroundColor: Colors.appWhite,
            .font: Fonts.bold(size: 18) as Any
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: Colors.appWhite,
            .font: Fonts.bold(size: 36) as Any,
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        let tabAppearance = UITabBarAppearance()
        updateTabBarItemAppearance(appearance: tabAppearance.compactInlineLayoutAppearance)
        updateTabBarItemAppearance(appearance: tabAppearance.inlineLayoutAppearance)
        updateTabBarItemAppearance(appearance: tabAppearance.stackedLayoutAppearance)
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = Colors.appWhite
        UITabBar.appearance().standardAppearance = tabAppearance
       // UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    } else {
        UITabBar.appearance().tintColor = Colors.appTint
        UINavigationBar.appearance().barTintColor = Colors.headerThemeColor
        UINavigationBar.appearance().backIndicatorImage = R.image.backWhite()
        UINavigationBar.appearance().backIndicatorTransitionMaskImage = R.image.backWhite()
        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: Colors.appWhite,
            .font: Fonts.bold(size: 18) as Any
        ]
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: Colors.appWhite,
            .font: Fonts.bold(size: 36) as Any,
        ]
        UINavigationBar.appearance().shadowImage = UIImage()
        UITabBarItem.appearance().setTitleTextAttributes([.foregroundColor: Colors.tabBarTextColorNormal], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes([.foregroundColor: Colors.tabBarTextColorSelected], for: .selected)
        // Fallback on earlier versions
    }
   
    if #available(iOS 13.0, *) {
        //NOTE: Hides back button text
        let titleTextAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.clear
        ]
        UINavigationBar.appearance().standardAppearance.backButtonAppearance.normal.titleTextAttributes = titleTextAttributes
        UINavigationBar.appearance().compactAppearance?.backButtonAppearance.normal.titleTextAttributes = titleTextAttributes
        UINavigationBar.appearance().scrollEdgeAppearance?.backButtonAppearance.normal.titleTextAttributes = titleTextAttributes
    } else {
        // Fallback on earlier versions
    }

    //We could have set the backBarButtonItem with an empty title for every view controller, but we don't have a place to do it for Eureka view controllers. Using appearance here, while a hack is still more convenient though, since we don't have to do it for every view controller instance
    UIBarButtonItem.appearance().setBackButtonTitlePositionAdjustment(UIOffset(horizontal: -200, vertical: 0), for: .default)
    UIBarButtonItem.appearance().tintColor = Colors.appWhite
    UIBarButtonItem.appearance(whenContainedInInstancesOf: [UIToolbar.self]).tintColor = Colors.navigationButtonTintColor

    UIToolbar.appearance().tintColor = Colors.appTint

    //Background (not needed in iOS 12.1 on simulator)
    UISearchBar.appearance().backgroundColor = Colors.appBackground
    //Cancel button
    UISearchBar.appearance().tintColor = Colors.navigationButtonTintColor
    //Cursor color
    UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).tintColor = Colors.navigationTitleColor

    UIRefreshControl.appearance().tintColor = Colors.navigationTitleColor

    UISwitch.appearance().onTintColor = Colors.appTint
}

@available(iOS 13.0, *)
private func updateTabBarItemAppearance(appearance: UITabBarItemAppearance) {
    let tintColor: UIColor = Colors.tabBarTextColorSelected
    let unselectedItemTintColor: UIColor = Colors.tabBarTextColorNormal
    appearance.normal.titleTextAttributes = [.foregroundColor: unselectedItemTintColor]
    appearance.selected.titleTextAttributes = [.foregroundColor: tintColor]
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
    static let headerThemeColor = UIColor(hex: "152172")
    static let tabBarTextColorNormal = UIColor(hex: "898DB4")
    static let tabBarTextColorSelected = UIColor(hex: "152172")
    static let appBackground = UIColor(hex: "F5F5F5")
    static let appTint = R.color.azure()!
    static let navigationTitleColor = UIColor.black
    static let navigationButtonTintColor = R.color.mine()!
    static let appWhite = UIColor.white
    static let appText = UIColor(red: 21, green: 33, blue: 114)
    static let appSubtitle = UIColor(red: 117, green: 117, blue: 117)
    static let appHighlightGreen = UIColor(red: 117, green: 185, blue: 67)
    static let appActionButtonGreen = UIColor(red: 21, green: 33, blue: 114)
    static let disabledActionButton = UIColor(hex: "d7ebc8")
    static let appActionButtonShadow = UIColor.clear
    static let appGreenContrastBackground = UIColor(red: 86, green: 153, blue: 8)
    static let appLightButtonSeparator = UIColor(red: 255, green: 255, blue: 255, alpha: 0.2)
    static let appRed = UIColor(red: 204, green: 71, blue: 65)
    static let apprecationRed = UIColor(hex: "ff3b30")
    static let apprecationGreen = Colors.appHighlightGreen
    static let appGrayLabel = UIColor(red: 155, green: 155, blue: 155)
    static let settingsSubtitle = UIColor(red: 141, green: 141, blue: 141)
    static let qrCodeRectBorders = UIColor(red: 216, green: 216, blue: 216)
    static let loadingIndicatorBorder = UIColor(red: 237, green: 237, blue: 237)
    static let sortByTextColor = UIColor(red: 51, green: 51, blue: 51)
    static let segmentIndicatorColor = UIColor(hex: "E7A634")
    static let borderGrayColor = UIColor(hex: "c4cad1")
    static let settingsBackGroundColor = UIColor(hex: "E9ECEF")
    static let clear = UIColor.clear
    static let priceColor = UIColor(hex: "808392")
    static let newBorder = UIColor(hex: "C4CAD1")

}

struct StyleLayout {
    static let sideMargin: CGFloat = 15
}

struct Fonts {
    
    static func light(size: CGFloat) -> UIFont {
        return UIFont(resource: R.font.spaceTextLight, size: size)!
    }
    
    static func regular(size: CGFloat) -> UIFont {
        return UIFont(resource: R.font.spaceTextRegular, size: size)!
    }
    
    static func semibold(size: CGFloat) -> UIFont {
        return UIFont(resource: R.font.spaceTextSemiBold, size: size)!
    }
    
    static func bold(size: CGFloat) -> UIFont {
        return UIFont(resource: R.font.spaceTextBold, size: size)!
    }
    
    static func spaceMedium(size: CGFloat) -> UIFont {
        return UIFont(resource: R.font.spaceTextMedium, size: size)!
    }
    
    static let tableHeader = Fonts.semibold(size: 15)
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
        static let backUp = CGFloat(10)
        static let textbox = CGFloat(5)
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
        static let background = R.color.alabaster()!
        static let cellSeparator = UIColor(red: 233, green: 233, blue: 233)
    }
}

enum Table {
    enum Metric {
        static let plainLeftMargin = CGFloat(5)

    }
}

enum DataEntry {
    //NOTE: Helper method to decrease line width ;)
    private static var isNarrowScreen: Bool {
        ScreenChecker().isNarrowScreen
    }

    enum Color {
        static let newBorder = Colors.newBorder
        static let border = UIColor(red: 194, green: 194, blue: 194)
        static let text = Colors.appText
        static let label = Colors.appGrayLabel
        static let textFieldStatus = R.color.danger()
        static let icon = Colors.appTint
        static let secondary = Colors.appGrayLabel
        static let textFieldError = R.color.danger()!
        static let textFieldShadowWhileEditing = Colors.appTint
        static let textFieldBackground = UIColor(hex: "FBFBFB")
        static let placeholder = UIColor(hex: "919191")
        static let pasteColor = UIColor(hex: "4c79cb")
        static let ensText = UIColor(red: 117, green: 185, blue: 67)
        static let searchTextFieldBackground = UIColor(red: 243, green: 244, blue: 245)
    }

    enum Metric {
        static let borderThickness = CGFloat(1.0)
        static let cornerRadius = Metrics.CornerRadius.textbox
        static let shadowRadius = CGFloat(2.0)
        static let textFieldInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        static let currencyIconInset = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)

        enum SendHeader {
            static let iconSide: CGFloat = 40
            static let insets = UIEdgeInsets(top: isNarrowScreen ? 20 : 40, left: 0, bottom: 0, right: 0)
            static let topSpacerHeight: CGFloat = isNarrowScreen ? 10 : 20

            enum RecentTransactionsLabel {
                static let height: CGFloat = isNarrowScreen ? 40 : 50
                static let edgeInsets: UIEdgeInsets = .init(top: 0, left: isNarrowScreen ? 15 : 30, bottom: 0, right: 0)
            }
        }

        enum Tokens {
            enum Filter {
                static let height: CGFloat = isNarrowScreen ? 40 : 50
            }
        }

        enum AddHideToken {
            enum Header {
                static let height: CGFloat = 70
            }
        }

        enum TableView {
            static let estimatedRowHeight: CGFloat = 100
            static let headerReferenceSizeWidth: CGFloat = 100
        }

        enum ButtonsBar {
            static let insets: UIEdgeInsets = .init(top: 20, left: 0, bottom: 20, right: 0)
            static let separatorHeight: CGFloat = 1.0
        }

        enum TransactionConfirmation {
            static let separatorHeight: CGFloat = 1.0
            static let headerHeight: CGFloat = isNarrowScreen ? 50 : 60
            static let footerHeight: CGFloat = isNarrowScreen ? 80 : 120
        }

        enum AddressTextField {
            //NOTE: top/bottom insets value to allow shadow displaying
            static let insets: UIEdgeInsets = .init(top: shadowRadius, left: shadowRadius, bottom: shadowRadius, right: shadowRadius)
        }
    }

    enum Font {
        static let text = Fonts.regular(size: isNarrowScreen ? 14: 18)
        static let label = Fonts.bold(size: 13)
        static let textFieldTitle = Fonts.regular(size: 13)
        static let textFieldStatus = Fonts.bold(size: 13)
        static let textField = Fonts.regular(size: isNarrowScreen ? 14: 17)
        static let accessory = Fonts.bold(size: isNarrowScreen ? 14: 17)
        static let regularButton = Fonts.regular(size: isNarrowScreen ? 14: 17)
        static let amountTextField = Fonts.regular(size: isNarrowScreen ? 18: 36)
    }
}

enum Label {
    enum Font {
        static let text = Fonts.regular(size: 18)
    }
}

enum Screen {

    enum Tokens {
        static let addHideTokenFont = Fonts.bold(size: 14)
    }

    enum Backup {
        static let subtitleFont = ScreenChecker().isNarrowScreen ? Fonts.regular(size: 22) : Fonts.regular(size: 28)
        static let newSubtitleFont = ScreenChecker().isNarrowScreen ? Fonts.regular(size: 16) : Fonts.regular(size: 18)
        static let subtitleColor = Colors.darkGray
        static let descriptionFont = Fonts.regular(size: ScreenChecker.size(big: 17, medium: 15, small: 15))
        static let descriptionBoldFont = Fonts.bold(size: ScreenChecker.size(big: 17, medium: 15, small: 15))
        static let descriptionFontSmall = Fonts.regular(size: ScreenChecker.size(big: 13, medium: 13, small: 9))
        static let descriptionColor = Colors.darkGray
        static let WalletHeaderValue = Fonts.regular(size: 20)
        static let WalletDescValue = Fonts.regular(size: 10)
    }

    enum Setting {
        enum Font {
            static let title = Fonts.regular(size: 17)
            static let subtitle = Fonts.regular(size: 12)
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
            static let title: UIFont = Fonts.bold(size: 14)
            static let titleBold: UIFont = Fonts.regular(size: 16)
            static let subtitle = Fonts.regular(size: 15)
            static let blockChainName = Fonts.semibold(size: 12)
            static let valueChangeLabel = Fonts.regular(size: 15)
            static let placeholderLabel = Fonts.regular(size: 17)
            static let valueChangeValue = Fonts.semibold(size: 17)
            static let WalletHeaderValue = Fonts.semibold(size: 12)
        }

        enum Color {
            static let background = Colors.appBackground
            static let title = Colors.appText
            static let subtitle = Colors.appSubtitle
            static let valueChangeLabel = Colors.appGrayLabel
            static func valueChangeValue(ticker: CoinTicker?, emptyValueColor: UIColor = Colors.appGrayLabel) -> UIColor {
                switch EthCurrencyHelper(ticker: ticker).change24h {
                case .appreciate:
                    return Colors.apprecationGreen
                case .depreciate:
                    return Colors.apprecationRed
                case .none:
                    return emptyValueColor
                }
            }
            static let blockChainName = Colors.appWhite
        }

        enum Metric {
            static let blockChainTagCornerRadius = CGFloat(4)
            static let blockChainTagHeight = CGFloat(20)
        }
    }

    enum TransactionConfirmation {
        static var transactionRowInfoInsets: UIEdgeInsets {
            let leftRightInset: CGFloat = ScreenChecker().isNarrowScreen ? 10 : 24
            let topBottomInset: CGFloat = ScreenChecker().isNarrowScreen ? 5 : 8
            return .init(top: 0, left: leftRightInset, bottom: topBottomInset, right: leftRightInset)
        }
    }
}
