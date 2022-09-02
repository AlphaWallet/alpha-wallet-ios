// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

func applyStyle() {
    UIBarButtonItem.appearance(whenContainedInInstancesOf: [UIDocumentBrowserViewController.self]).tintColor = Configuration.Color.Semantic.navigationbarButtonItemTint
    UIWindow.appearance().tintColor = Colors.appTint

    UINavigationBar.appearance().shadowImage = UIImage(color: Style.NavigationBar.Separator.color, size: CGSize(width: 0.25, height: 0.25))
    UINavigationBar.appearance().compactAppearance = UINavigationBarAppearance.defaultAppearence
    UINavigationBar.appearance().standardAppearance = UINavigationBarAppearance.defaultAppearence
    UINavigationBar.appearance().scrollEdgeAppearance = UINavigationBarAppearance.defaultAppearence

    //We could have set the backBarButtonItem with an empty title for every view controller. Using appearance here, while a hack is still more convenient though, since we don't have to do it for every view controller instance
    UIBarButtonItem.appearance().setBackButtonTitlePositionAdjustment(UIOffset(horizontal: -200, vertical: 0), for: .default)
    UIBarButtonItem.appearance().tintColor = Configuration.Color.Semantic.navigationbarButtonItemTint
    UIBarButtonItem.appearance(whenContainedInInstancesOf: [UIToolbar.self]).tintColor = Configuration.Color.Semantic.navigationbarButtonItemTint

    UIToolbar.appearance().tintColor = Colors.appTint

    //Background (not needed in iOS 12.1 on simulator)
    UISearchBar.appearance().backgroundColor = Colors.appBackground
    //Cancel button
    UISearchBar.appearance().tintColor = Configuration.Color.Semantic.searchbarTint
    //Cursor color
    UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).tintColor = Configuration.Color.Semantic.searchbarTint

    UIRefreshControl.appearance().tintColor = Colors.navigationTitleColor

    UISwitch.appearance().onTintColor = Colors.appTint

    UITableView.appearance().separatorColor = Configuration.Color.Semantic.tableViewSeparator
}

extension UINavigationBarAppearance {
    static var defaultAppearence: UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Configuration.Color.Semantic.navigationbarBackgroundColor
        appearance.shadowColor = Configuration.Color.Semantic.navigationbarSeparator
        appearance.shadowImage = nil
        appearance.setBackIndicatorImage(R.image.backWhite(), transitionMaskImage: R.image.backWhite())
        appearance.titleTextAttributes = [
            .foregroundColor: Configuration.Color.Semantic.navigationbarPrimaryFont,
            .font: Fonts.semibold(size: 17) as Any
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: Configuration.Color.Semantic.navigationbarPrimaryFont,
            .font: Fonts.bold(size: 36) as Any,
        ]
        //NOTE: Hides back button text
        appearance.backButtonAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.clear
        ]

        return appearance
    }
}

extension UITabBarAppearance {
    static var defaultAppearence: UITabBarAppearance {
        let tabBarAppearance = UITabBarAppearance()

        tabBarAppearance.backgroundColor = Configuration.Color.Semantic.tabBarBackground
        tabBarAppearance.shadowColor = Configuration.Color.Semantic.tabBarSeparator

        let tabBarItemAppearance = UITabBarItemAppearance()

        tabBarItemAppearance.normal.titleTextAttributes = [.font: Style.TabBar.Font.normal, .foregroundColor: Style.TabBar.Color.normal]
        tabBarItemAppearance.selected.titleTextAttributes = [.font: Style.TabBar.Font.selected, .foregroundColor: Style.TabBar.Color.selected]

        tabBarAppearance.stackedLayoutAppearance = tabBarItemAppearance

        return tabBarAppearance
    }
}

extension UITabBarController {
    static func withOverridenBarAppearence(appearence tabBarAppearance: UITabBarAppearance = .defaultAppearence) -> UITabBarController {
        let tabBarController = UITabBarController()
        tabBarController.tabBar.isTranslucent = false
        tabBarController.tabBar.tintColor = Configuration.Color.Semantic.tabBarTint
        tabBarController.tabBar.standardAppearance = tabBarAppearance

        if #available(iOS 15.0, *) {
            tabBarController.tabBar.scrollEdgeAppearance = tabBarAppearance
        } else {
            // Fallback on earlier versions
        }

        return tabBarController
    }
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
    static let clear = UIColor.clear
    static let appBackground = UIColor.white
    static let appTint = R.color.azure()!
    static let navigationTitleColor = UIColor.black
    // static let navigationButtonTintColor = R.color.mine()!
    static let appWhite = UIColor.white
    static let appText = R.color.black()!
    static let appSubtitle = UIColor(red: 117, green: 117, blue: 117)
    static let appHighlightGreen = UIColor(red: 117, green: 185, blue: 67)
    static let appActionButtonGreen = UIColor(red: 105, green: 200, blue: 0)
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
}

struct StyleLayout {
    static let sideMargin: CGFloat = 15
}

struct Fonts {
    static func regular(size: CGFloat) -> UIFont {
        return UIFont(resource: R.font.sourceSansProRegular, size: size)!
    }
    static func semibold(size: CGFloat) -> UIFont {
        return UIFont(resource: R.font.sourceSansProSemibold, size: size)!
    }
    static func bold(size: CGFloat) -> UIFont {
        return UIFont(resource: R.font.sourceSansProBold, size: size)!
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
        static let textbox = CGFloat(5)
        static let button = CGFloat(4)
        static let nftBox = CGFloat(8)
    }

    enum DappsHome {
        enum Icon {
            static let shadowOffset = CGSize(width: 0, height: 0)
            static let shadowOpacity = Float(0.15)
            static let shadowRadius = CGFloat(6)
            static let shadowColor = UIColor.black
        }
    }

    static let tokenChainOverlayDimension = CGFloat(16)
    static let anArbitraryRowHeightSoAutoSizingCellsWorkIniOS10 = CGFloat(100)
    enum Analytics {
        static let spacing = CGFloat(30)
        static let edgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    }
}

enum GroupedTable {
    enum Metric {
        static let cellSpacing = CGFloat(5)
        static let cellSeparatorHeight = CGFloat(1)
    }

    enum Color {
        static let title = R.color.black()!
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
        static let ensText = UIColor(red: 117, green: 185, blue: 67)
        static let searchTextFieldBackground = UIColor(red: 243, green: 244, blue: 245)
    }

    enum Metric {
        static let borderThickness = CGFloat(1.0)
        static let cornerRadius = Metrics.CornerRadius.textbox
        static let shadowRadius = CGFloat(2.0)
        static let currencyIconInset = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)

        enum TextField {
            static let borderThickness = CGFloat(1.0)

            enum Default {
                static let edgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
                static let cornerRadius: CGFloat = Metrics.CornerRadius.textbox
                static let textInset: CGSize = .zero
                static let height: CGFloat = ScreenChecker().isNarrowScreen ? 30 : 50
            }
            
            enum Rounded {
                static let edgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
                static let cornerRadius: CGFloat = height / 2
                static let height: CGFloat = ScreenChecker().isNarrowScreen ? 30 : 40
                static let textInset: CGSize = CGSize(width: 5, height: 0)
            }
        }

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
                static let height: CGFloat = isNarrowScreen ? 50 : 60
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
        static let addHideTokenFont = Fonts.semibold(size: 17)
    }

    enum Backup {
        static let subtitleFont = ScreenChecker().isNarrowScreen ? Fonts.regular(size: 22) : Fonts.regular(size: 28)
        static let subtitleColor = Colors.darkGray
        static let descriptionFont = Fonts.regular(size: ScreenChecker.size(big: 17, medium: 15, small: 15))
        static let descriptionBoldFont = Fonts.bold(size: ScreenChecker.size(big: 17, medium: 15, small: 15))
        static let descriptionColor = Colors.darkGray
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
            static let title: UIFont = Fonts.regular(size: 20)
            static let subtitle = Fonts.regular(size: 15)
            static let blockChainName = Fonts.semibold(size: 12)
            static let valueChangeLabel = Fonts.regular(size: 15)
            static let placeholderLabel = Fonts.regular(size: 17)
            static let valueChangeValue = Fonts.semibold(size: 20)
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

enum Style {
    enum SearchBar {
        static let height = 50.0
    }
    enum Animation {
        static let duration = 0.5
        static let curve: UIView.AnimationCurve = .easeInOut
    }
    enum Wallet {
        enum Header {
            static let height = 60.0
            static let backgroundColor = R.color.alabaster()
            static let textColor = R.color.dove()
            static let font = Fonts.semibold(size: 15)
        }
        enum Row {
            static let height = 80.0
            static let collectiblePairsHeight = 250.0
        }
    }
    enum SelectionIndicator {
        static let height = 8.0
        static let width = 8.0
        static let leadingOffset = 8.0
        static let color = R.color.azure()
    }
    enum AccessoryView {
        static var chevron: UIImageView {
            let imageView = UIImageView(image: R.image.iconsSystemArrowRight())
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: 24.0),
                imageView.heightAnchor.constraint(equalToConstant: 24.0)
            ])
            return imageView
        }
    }
    enum TableView {
        enum Separator {
            static let color: UIColor = R.color.mercury()!
        }
        enum ChangeWalletCell {
            static let height: CGFloat = 80.0
        }
    }
    enum TabBar {
        enum Background {
            static let tint: UIColor = Colors.appTint
            static let color: UIColor = {
                return UIColor.systemBackground
            }()
        }
        enum Separator {
            static let color: UIColor = R.color.mercury()!
        }
        enum Font {
            static let normal: UIFont = Fonts.regular(size: 13)
            static let selected: UIFont = Fonts.semibold(size: 13)
        }
        enum Color {
            static let selected: UIColor = R.color.azure()!
            static let normal: UIColor = R.color.dove()!
        }
    }
    enum SegmentedControl {
        enum Separator {
            static let color: UIColor = R.color.mercury()!
        }
    }

    enum NavigationBar {
        enum Separator {
            static let color: UIColor = R.color.mercury()!
        }
    }
    enum RPCServerTableView {
        static let HeaderHeight: CGFloat = 50.0
        enum Cell {
            enum text {
                static let color: UIColor = R.color.black()!
            }
            enum detailedText {
                static let color: UIColor = R.color.dove()!
            }
            enum tint {
                static let color: UIColor = R.color.azure()!
            }
        }
    }
    enum Search {
        enum Network {
            enum Empty {
                static let font = Fonts.regular(size: 17)
                static let color: UIColor = R.color.mine()!
                static let text: String = R.string.localizable.searchNetworkResultEmpty()
            }
        }
    }
    enum ScrollableSegmentedControl {
        static let configuration = ScrollableSegmentedControlConfiguration(lineConfiguration: ScrollableSegmentedControlHighlightableLineViewConfiguration(lineHeight: 1.0, highlightHeight: 3.0, lineColor: Configuration.Color.Semantic.scrollableSegmentedControlLineColor, highLightColor: Configuration.Color.Semantic.scrollableSegmentedControllerHighlightColor), isProportionalWidth: true, cellSpacing: 10.0, alignmentWhenNotScrollable: .filled, animationDuration: 0.25, animationCurve: .easeInOut)
    }
    enum ScrollableSegmentedControlCell {
        static let configuration = ScrollableSegmentedControlCellConfiguration(backgroundColor: Configuration.Color.Semantic.scrollableSegmentedControllerBackground, highlightedTextColor: R.color.azure()!, nonHighlightedTextColor: Configuration.Color.Semantic.scrollableSegmentedControllerNonHighlightColor, highlightedFont: Fonts.semibold(size: 15), nonHighlightedFont: Fonts.regular(size: 15), cellPadding: 8.0, textBottomPadding: 12.0)
    }
    enum value {
        static let appreciated: UIColor = R.color.green()!
        static let depreciated: UIColor = R.color.danger()!
    }
    enum insets {
        static let safeBottom: CGFloat = 2.0
    }
}
