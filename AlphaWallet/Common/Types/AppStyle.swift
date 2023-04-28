// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

func applyStyle() {
    UIBarButtonItem.appearance(whenContainedInInstancesOf: [UIDocumentBrowserViewController.self]).tintColor = Configuration.Color.Semantic.navigationBarButtonItemTint
    UIWindow.appearance().tintColor = Configuration.Color.Semantic.appTint

    UINavigationBar.appearance().shadowImage = UIImage(color: Configuration.Color.Semantic.navigationBarSeparator, size: CGSize(width: 0.25, height: 0.25))
    UINavigationBar.appearance().compactAppearance = UINavigationBarAppearance.defaultAppearence
    UINavigationBar.appearance().standardAppearance = UINavigationBarAppearance.defaultAppearence
    UINavigationBar.appearance().scrollEdgeAppearance = UINavigationBarAppearance.defaultAppearence

    //We could have set the backBarButtonItem with an empty title for every view controller. Using appearance here, while a hack is still more convenient though, since we don't have to do it for every view controller instance
    UIBarButtonItem.appearance().setBackButtonTitlePositionAdjustment(UIOffset(horizontal: -200, vertical: 0), for: .default)
    UIBarButtonItem.appearance().tintColor = Configuration.Color.Semantic.navigationBarButtonItemTint
    UIBarButtonItem.appearance(whenContainedInInstancesOf: [UIToolbar.self]).tintColor = Configuration.Color.Semantic.navigationBarButtonItemTint

    UIToolbar.appearance().tintColor = Configuration.Color.Semantic.appTint

    //Background (not needed in iOS 12.1 on simulator)
    //Cancel button
    UISearchBar.appearance().tintColor = Configuration.Color.Semantic.searchBarTint
    //Cursor color
    UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).tintColor = Configuration.Color.Semantic.searchBarTint

    UIRefreshControl.appearance().tintColor = Configuration.Color.Semantic.refreshControl

    UISwitch.appearance().onTintColor = Configuration.Color.Semantic.appTint

    UITableView.appearance().separatorColor = Configuration.Color.Semantic.tableViewSeparator
}

extension UINavigationBarAppearance {
    static var defaultAppearence: UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Configuration.Color.Semantic.navigationBarBackgroundColor
        appearance.shadowColor = Configuration.Color.Semantic.navigationBarSeparator
        appearance.shadowImage = nil
        appearance.setBackIndicatorImage(R.image.backWhite(), transitionMaskImage: R.image.backWhite())
        appearance.titleTextAttributes = [
            .foregroundColor: Configuration.Color.Semantic.navigationBarPrimaryFont,
            .font: Fonts.semibold(size: 17) as Any
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: Configuration.Color.Semantic.navigationBarPrimaryFont,
            .font: Fonts.bold(size: 36) as Any,
        ]
        //NOTE: Hides back button text
        appearance.backButtonAppearance.normal.titleTextAttributes = [
            .foregroundColor: Configuration.Color.Semantic.backButtonText
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

        tabBarItemAppearance.normal.titleTextAttributes = [
            .font: Fonts.regular(size: 13),
            .foregroundColor: Configuration.Color.Semantic.tabBarUnselected
        ]
        tabBarItemAppearance.selected.titleTextAttributes = [
            .font: Fonts.semibold(size: 13),
            .foregroundColor: Configuration.Color.Semantic.appTint
        ]

        tabBarAppearance.stackedLayoutAppearance = tabBarItemAppearance

        return tabBarAppearance
    }
}

extension TabBarController {
    static func withOverridenBarAppearence(appearence tabBarAppearance: UITabBarAppearance = .defaultAppearence) -> TabBarController {
        let tabBarController = TabBarController()
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

class TabBarController: UITabBarController, PopInteractable {
    func shouldBeginPopInteraction() -> Bool {
        return false
    }
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
}

enum DataEntry {
    enum Metric {
        enum CornerRadius {
            static let popups = CGFloat(20)
            static let box = CGFloat(2)
            static let textbox = CGFloat(5)
            static let button = CGFloat(4)
            static let nftBox = CGFloat(8)
        }

        static let borderThickness = CGFloat(1.0)
        static let cornerRadius = CornerRadius.textbox
        static let shadowRadius = CGFloat(2.0)
        static let currencyIconInset = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
        static let sideInset = ScreenChecker.size(big: 20, medium: 20, small: 16)
        static let anArbitraryRowHeightSoAutoSizingCellsWorkIniOS10 = CGFloat(100)
        static let sideMargin: CGFloat = 15
        static let safeBottom: CGFloat = 2.0

        enum DappsHome {
            enum Icon {
                static let shadowOffset = CGSize(width: 0, height: 0)
                static let shadowOpacity = Float(0.15)
                static let shadowRadius = CGFloat(6)
                static let shadowColor = Configuration.Color.Semantic.dappsIconShadow
            }
        }

        enum Analytics {
            static let spacing = CGFloat(30)
            static let edgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        }

        enum TextField {
            static let borderThickness = CGFloat(1.0)

            enum Default {
                static let edgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
                static let cornerRadius: CGFloat = CornerRadius.textbox
                static let textInset: CGSize = CGSize(width: 5, height: 0)
                static let height: CGFloat = ScreenChecker.size(big: 50, medium: 50, small: 38)
                static let spaceFromTitleToTextField: CGFloat = 4
                static let spaceFromTextFieldToStatusLabel: CGFloat = 4
                static let controlsContainerHeight: CGFloat = ScreenChecker.size(big: 30, medium: 30, small: 25)
            }
            
            enum Rounded {
                static let edgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
                static let cornerRadius: CGFloat = height / 2
                static let height: CGFloat = ScreenChecker.size(big: 40, medium: 40, small: 30)
                static let textInset: CGSize = CGSize(width: 5, height: 0)
            }
        }

        enum SendHeader {
            static let iconSide: CGFloat = 40
            static let insets = UIEdgeInsets(top: ScreenChecker.size(big: 40, medium: 40, small: 20), left: 0, bottom: 0, right: 0)
            static let topSpacerHeight: CGFloat = ScreenChecker.size(big: 20, medium: 20, small: 10)

            enum RecentTransactionsLabel {
                static let height: CGFloat = ScreenChecker.size(big: 50, medium: 50, small: 40)
                static let edgeInsets: UIEdgeInsets = .init(top: 0, left: ScreenChecker.size(big: 30, medium: 30, small: 15), bottom: 0, right: 0)
            }
        }

        enum Wallets {
            static let headerHeight: CGFloat = 60.0
        }

        enum Tokens {
            enum Filter {
                static let height: CGFloat = ScreenChecker.size(big: 50, medium: 50, small: 40)
            }
            static let headerHeight: CGFloat = 60.0
            static let cellHeight: CGFloat = 80.0
            static let collectiblePairsHeight = 250.0
        }

        enum AddHideToken {
            enum Header {
                static let height: CGFloat = ScreenChecker.size(big: 60, medium: 60, small: 50)
            }
        }

        enum TableView {
            static let estimatedRowHeight: CGFloat = 100
            static let headerReferenceSizeWidth: CGFloat = 100
            static let rpcServerHeader: CGFloat = 50
            static let changeWalletCell: CGFloat = 80

            static let groupedTableCellSpacing = CGFloat(5)
            static let groupedTableCellSeparatorHeight = CGFloat(1)
        }

        enum ButtonsBar {
            static let insets: UIEdgeInsets = .init(
                top: ScreenChecker.size(big: 20, medium: 20, small: 15),
                left: 0,
                bottom: ScreenChecker.size(big: 20, medium: 20, small: 15),
                right: 0)
            static let separatorHeight: CGFloat = 1.0
        }

        enum Cell {
            static let insets: UIEdgeInsets = .init(
                top: ScreenChecker.size(big: 20, medium: 20, small: 18),
                left: 15,
                bottom: ScreenChecker.size(big: 20, medium: 20, small: 18),
                right: 15)

            static let imageSize = CGSize(width: 40, height: 40)
        }

        enum ChainOverlay {
            static let size = CGSize.init(width: 16, height: 16)
        }

        enum TransactionConfirmation {
            static let separatorHeight: CGFloat = 1.0
            static let headerHeight: CGFloat = ScreenChecker.size(big: 60, medium: 60, small: 50)
            static let footerHeight: CGFloat = ScreenChecker.size(big: 120, medium: 120, small: 80)
            static var transactionRowInfoInsets: UIEdgeInsets {
                let leftRightInset: CGFloat = ScreenChecker.size(big: 24, medium: 24, small: 10)
                let topBottomInset: CGFloat = ScreenChecker.size(big: 8, medium: 8, small: 5)
                return .init(top: 0, left: leftRightInset, bottom: topBottomInset, right: leftRightInset)
            }
        }

        enum AddressTextField {
            //NOTE: top/bottom insets value to allow shadow displaying
            static let insets: UIEdgeInsets = .init(top: shadowRadius, left: shadowRadius, bottom: shadowRadius, right: shadowRadius)
        }

        enum ImageView {
            static let serverIconSize = CGSize(width: 20, height: 20)
        }

        enum TabBar {
            static let height: CGFloat = ScreenChecker.size(big: 44, medium: 44, small: 38)
        }

        enum Container {
            static let xMargin = CGFloat(16)
        }

        enum SelectionIndicator {
            static let height = 8.0
            static let width = 8.0
            static let leadingOffset = 8.0
        }

        enum BlockChainTag {
            static let cornerRadius = CGFloat(4)
            static let height = CGFloat(20)
        }

        enum SearchBar {
            static let height = 50.0
        }
    }
}

enum Screen {

    enum Backup {
        static let subtitleFont = Fonts.regular(size: ScreenChecker.size(big: 28, medium: 28, small: 22))
        static let subtitleColor = Configuration.Color.Semantic.alternativeText
        static let descriptionFont = Fonts.regular(size: ScreenChecker.size(big: 17, medium: 15, small: 15))
        static let descriptionBoldFont = Fonts.bold(size: ScreenChecker.size(big: 17, medium: 15, small: 15))
        static let descriptionColor = Configuration.Color.Semantic.alternativeText
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
            static let title = Configuration.Color.Semantic.defaultForegroundText
            static let subtitle = Configuration.Color.Semantic.defaultSubtitleText
            static let valueChangeLabel = Configuration.Color.Semantic.alternativeText
            static func valueChangeValue(ticker: CoinTicker?, emptyValueColor: UIColor = Configuration.Color.Semantic.alternativeText) -> UIColor {
                switch TickerHelper(ticker: ticker).change24h {
                case .appreciate:
                    return Configuration.Color.Semantic.appreciation
                case .depreciate:
                    return Configuration.Color.Semantic.depreciation
                case .none:
                    return emptyValueColor
                }
            }
            static let blockChainName = Configuration.Color.Semantic.defaultInverseText
        }
    }
}

enum Style {
    enum Animation {
        static let duration = 0.5
        static let curve: UIView.AnimationCurve = .easeInOut
    }

    enum ScrollableSegmentedControl {
        static let configuration = ScrollableSegmentedControlConfiguration(lineConfiguration: ScrollableSegmentedControlHighlightableLineViewConfiguration(lineHeight: 1.0, highlightHeight: 3.0, lineColor: Configuration.Color.Semantic.scrollableSegmentedControlLineColor, highLightColor: Configuration.Color.Semantic.scrollableSegmentedControllerHighlightColor), isProportionalWidth: true, cellSpacing: 10.0, alignmentWhenNotScrollable: .filled, animationDuration: 0.25, animationCurve: .easeInOut)
    }
    enum ScrollableSegmentedControlCell {
        static let configuration = ScrollableSegmentedControlCellConfiguration(backgroundColor: Configuration.Color.Semantic.scrollableSegmentedControllerBackground, highlightedTextColor: R.color.azure()!, nonHighlightedTextColor: Configuration.Color.Semantic.scrollableSegmentedControllerNonHighlightColor, highlightedFont: Fonts.semibold(size: 15), nonHighlightedFont: Fonts.regular(size: 15), cellPadding: 8.0, textBottomPadding: 12.0)
    }
}

extension UIImageView {
    static var chevronImageView: UIImageView {
        let imageView = UIImageView(image: R.image.iconsSystemArrowRight())
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 24.0),
            imageView.heightAnchor.constraint(equalToConstant: 24.0)
        ])
        return imageView
    }
}
