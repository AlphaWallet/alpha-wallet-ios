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
    }
}

struct Configuration {
    struct Color {
        struct Semantic {
            static let defaultViewBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.cod()!)
            }
            static let defaultForegroundText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }
            static let defaultSubtitleText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.dove()!, darkColor: R.color.dusty()!)
            }

            static let indicator = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.azure()!, darkColor: R.color.dodge()!)
            }

            static let defaultAttributedString = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.azure()!, darkColor: R.color.dodge()!)
            }

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
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.dusty()!)
            }
            static let secondaryButtonHighlightedBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.concrete()!, darkColor: R.color.dusty()!)
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

            static let textFieldBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.alabaster()!, darkColor: R.color.venus()!)
            }

            static let textViewBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.alabaster()!, darkColor: R.color.venus()!)
            }

            static let shadow = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }
        }
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

    static func defaultLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        return decorateAsDefaultLabel(label)
    }

    @discardableResult static func decorateAsDefaultLabel(_ label: UILabel) -> UILabel {
        label.textColor = Configuration.Color.Semantic.defaultForegroundText
        return label
    }

}
