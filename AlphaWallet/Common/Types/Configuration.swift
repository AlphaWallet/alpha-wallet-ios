//
//  Configuration.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 30/5/22.
//

import UIKit

fileprivate func colorFrom(trait: UITraitCollection, lightColor: UIColor, darkColor: UIColor) -> UIColor {
    switch trait.userInterfaceStyle {
    case .unspecified, .light:
        return lightColor
    case .dark:
        return darkColor
    @unknown default:
        return lightColor
    }
}

struct Configuration {
    struct Color {
        struct Semantic {
            static let borderClear = UIColor.clear
            static let backgroundClear = UIColor.clear
            static let defaultViewBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.cod()!)
            }
            static let defaultForegroundText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }
            static let defaultInverseText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.black()!)
            }
            static let defaultSubtitleText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.dove()!, darkColor: R.color.dusty()!)
            }
            static let defaultTitleText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: .black, darkColor: .white)
            }
            static let defaultHeadlineText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mine()!, darkColor: R.color.white()!)
            }
            static let indicator = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.azure()!, darkColor: R.color.dodge()!)
            }
            static let loading = R.color.loadingBackground()!
            static let loadingIndicatorBorder = UIColor(red: 237, green: 237, blue: 237)
            static let alternativeText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: .darkGray, darkColor: .lightGray)
            }

            static let defaultErrorText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.danger()!, darkColor: R.color.danger()!)
            }

            static let defaultAttributedString = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.azure()!, darkColor: R.color.dodge()!)
            }

            static let disabledActionButton = UIColor(hex: "d7ebc8")
            static let qrCodeRectBorders = UIColor(red: 216, green: 216, blue: 216)
            
            static let primaryButtonBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.cod()!, darkColor: R.color.alabaster()!)
            }
            static let primaryButtonHighlightedBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.concrete()!)
            }
            static let primaryButtonBackgroundInactive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mike()!, darkColor: R.color.mine()!)
            }
            static let primaryButtonBorderInactive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mike()!, darkColor: R.color.mine()!)
            }
            static let primaryButtonTextActive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.black()!)
            }
            static let primaryButtonTextInactive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.black()!)
            }
            static let primaryButtonBorderActive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.cod()!, darkColor: R.color.alabaster()!)
            }

            static let secondaryButtonBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.black()!)
            }
            static let secondaryButtonHighlightedBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.concrete()!, darkColor: R.color.black()!)
            }
            static let secondaryButtonBackgroundInactive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mike()!, darkColor: R.color.dusty()!)
            }
            static let secondaryButtonBorderInactive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mike()!, darkColor: R.color.dusty()!)
            }
            static let secondaryButtonTextActive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }
            static let secondaryButtonTextInactive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }
            static let secondaryButtonBorderActive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.dusty()!)
            }

            static let periodButtonSelectedText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.cod()!)
            }
            static let periodButtonSelectedBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: .darkGray, darkColor: .lightGray)
            }
            static let periodButtonNormalText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.cod()!, darkColor: R.color.white()!)
            }
            static let periodButtonNormalBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.cod()!)
            }
            static let defaultButtonBorder = R.color.alabaster()!
            static let actionButtonBackground = UIColor(red: 105, green: 200, blue: 0)
            static let actionButtonShadow = UIColor.clear
            static let cancelButtonTitle = R.color.danger()!
            static let deleteButtonTitle = R.color.danger()!
            static let defaultNote = R.color.danger()!

            static let labelTextActive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mine()!, darkColor: R.color.white()!)
            }

            static let tableViewBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.cod()!)
            }
            static let tableViewCellBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.cod()!)
            }
            static let tableViewCellPrimaryFont = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }
            static let tableViewCellSecondaryFont = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.dove()!, darkColor: R.color.dusty()!)
            }
            static let placeholderText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.dusty()!, darkColor: R.color.porcelain()!)
            }
            static let tableViewAccessory = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }
            static let tableViewAccessoryBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.alabaster()!, darkColor: R.color.venus()!)
            }
            static let tableViewHeaderBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.alabaster()!, darkColor: R.color.venus()!)
            }
            static let tableViewHeaderPrimaryFont = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }

            static let tableViewSeparator = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mercury()!, darkColor: R.color.venus()!)
            }

            static let tableViewSpecialBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.solitude()!, darkColor: R.color.mine()!)
            }

            static let refreshControl = UIColor { trait in
                return colorFrom(trait: trait, lightColor: .black, darkColor: .white)
            }
            
            static let collectionViewCellBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.cod()!)
            }
            static let searchbarTint = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mine()!, darkColor: R.color.white()!)
            }

            static let navigationbarBackgroundColor = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.black()!)
            }

            static let navigationbarSeparator = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mercury()!, darkColor: R.color.venus()!)
            }

            static let navigationbarPrimaryFont = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }

            static let navigationbarButtonItemTint = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mine()!, darkColor: R.color.white()!)
            }

            static let popupBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mercury()!, darkColor: R.color.venus()!)
            }

            static let popupPrimaryFont = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }

            static let popupSecondaryFont = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mine()!, darkColor: R.color.white()!)
            }

            static let popupSeparator = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mercury()!, darkColor: R.color.venus()!)
            }

            static let popupSwipeIndicator = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!.withAlphaComponent(0.2), darkColor: R.color.white()!.withAlphaComponent(0.2))
            }

            static let scrollableSegmentedControlLineColor = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mercury()!, darkColor: R.color.venus()!)
            }

            static let scrollableSegmentedControllerHighlightColor = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.azure()!, darkColor: R.color.dodge()!)
            }

            static let scrollableSegmentedControllerBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.cod()!)
            }

            static let scrollableSegmentedControllerNonHighlightColor = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.dove()!, darkColor: R.color.dusty()!)
            }

            static let searchbarBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.cod()!)
            }

            static let tabBarBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.cod()!)
            }

            static let tabBarTint = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.azure()!, darkColor: R.color.dodge()!)
            }

            static let tabBarSeparator = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mercury()!, darkColor: R.color.venus()!)
            }

            static let collectionViewBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.shark()!)
            }

            static let overlayBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!.withAlphaComponent(0.3), darkColor: R.color.white()!.withAlphaComponent(0.3))
            }

            static let dialogBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.black()!)
            }

            static let textFieldIcon = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.alabaster()!, darkColor: R.color.venus()!)
            }

            static let textFieldContrastText = UIColor(red: 86, green: 153, blue: 8)
            
            static let textFieldBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.alabaster()!, darkColor: R.color.venus()!)
            }

            static let textViewBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.alabaster()!, darkColor: R.color.venus()!)
            }

            static let shadow = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }

            static let sendingState = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.solitude()!, darkColor: R.color.luckyPoint()!)
            }

            static let pendingState = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.cheese()!, darkColor: R.color.ocean()!)
            }
            static let roundButtonBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mike()!, darkColor: R.color.mine()!)
            }

            static let textViewFailed = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.silver()!, darkColor: R.color.porcelain()!)
            }
            static let progressDialogBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.alabaster()!, darkColor: R.color.venus()!)
            }

            static let dangerBackground = R.color.danger()!
            static let appreciation = UIColor(red: 117, green: 185, blue: 67)
            static let depreciation = R.color.danger()!
            static let pass = appreciation
            static let fail = depreciation

            static let border = UIColor(red: 194, green: 194, blue: 194)
            static let text = Colors.appText
            static let textFieldStatus = Configuration.Color.Semantic.defaultErrorText
            static let icon = Colors.appTint
            static let secondary = UIColor(red: 155, green: 155, blue: 155)
            static let textFieldShadowWhileEditing = Colors.appTint
            static let placeholder = UIColor(hex: "919191")
            static let ensText = UIColor(red: 117, green: 185, blue: 67)
            static let searchTextFieldBackground = UIColor(red: 243, green: 244, blue: 245)
            static let headerViewBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.venus()!)
            }
            static let symbol = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }
        }
    }
}

extension Configuration {
    enum Font {
        static let text = Fonts.regular(size: ScreenChecker.size(big: 18, medium: 18, small: 14))
        static let label = Fonts.bold(size: 13)
        static let textFieldTitle = Fonts.regular(size: 13)
        static let textFieldStatus = Fonts.bold(size: 13)
        static let textField = Fonts.regular(size: ScreenChecker.size(big: 17, medium: 17, small: 14))
        static let accessory = Fonts.bold(size: ScreenChecker.size(big: 17, medium: 17, small: 14))
        static let amountTextField = Fonts.regular(size: ScreenChecker.size(big: 36, medium: 36, small: 26))
    }
}

class UIKitFactory {

    static func defaultView(autoResizingMarkIntoConstraints: Bool = false) -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = autoResizingMarkIntoConstraints
        return decorateAsDefaultView(view)
    }

    @discardableResult static func decorateAsDefaultView(_ view: UIView) -> UIView {
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        return view
    }

    @discardableResult static func decorateAsDefaultView(_ views: [UIView]) -> [UIView] {
        return views.map { decorateAsDefaultView($0) }
    } 
}
