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
