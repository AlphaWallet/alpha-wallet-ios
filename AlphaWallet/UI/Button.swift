// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

enum ButtonSize: Int {
    case small
    case normal
    case large
    case extraLarge

    var height: CGFloat {
        switch self {
        case .small: return 32
        case .normal: return 44
        case .large: return 50
        case .extraLarge: return 64
        }
    }
}

enum ButtonStyle {
    case solid
    case squared
    case border
    case borderless
    case system
    case special
    case green

    var backgroundColor: UIColor {
        switch self {
        case .solid, .squared: return Colors.appTint
        case .border, .borderless: return Configuration.Color.Semantic.defaultViewBackground
        case .system: return .clear
        case .special: return R.color.concrete()!
        case .green: return ButtonsBarViewModel.primaryButton.buttonBackgroundColor
        }
    }

    var backgroundColorHighlighted: UIColor {
        switch self {
        case .solid, .squared: return Colors.appTint
        case .border: return Colors.appTint
        case .borderless: return Configuration.Color.Semantic.defaultViewBackground
        case .system: return .clear
        case .special: return R.color.concrete()!
        case .green: return ButtonsBarViewModel.primaryButton.buttonBackgroundColor
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .solid, .border: return 5
        case .squared, .borderless, .system: return 0
        case .special: return 12
        case .green: return ButtonsBarViewModel.primaryButton.buttonCornerRadius
        }
    }

    var font: UIFont {
        switch self {
        case .solid,
             .squared,
             .border,
             .borderless, .system, .special:
            return Fonts.semibold(size: 16)
        case .green: return ButtonsBarViewModel.primaryButton.buttonFont
        }
    }

    var textColor: UIColor {
        switch self {
        case .solid, .squared: return Colors.appWhite
        case .border, .borderless, .system, .special: return Configuration.Color.Semantic.defaultForegroundText
        case .green: return ButtonsBarViewModel.primaryButton.buttonTitleColor
        }
    }

    var textColorHighlighted: UIColor {
        switch self {
        case .solid, .squared: return UIColor(white: 1, alpha: 0.8)
        case .border: return Colors.appWhite
        case .borderless, .system, .special: return Configuration.Color.Semantic.defaultViewBackground
        case .green: return Colors.appWhite.withAlphaComponent(0.8)
        }
    }

    var borderColor: UIColor {
        switch self {
        case .solid, .squared, .border: return GroupedTable.Color.background
        case .borderless, .system, .special: return .clear
        case .green: return ButtonsBarViewModel.primaryButton.buttonBorderColor
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .solid, .squared, .borderless, .system, .special: return 0
        case .border: return 1
        case .green: return ButtonsBarViewModel.primaryButton.buttonBorderWidth
        }
    }
}

class Button: UIButton {
    var heightConstraint: NSLayoutConstraint?

    init(size: ButtonSize, style: ButtonStyle) {
        super.init(frame: .zero)
        apply(size: size, style: style)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func apply(size: ButtonSize, style: ButtonStyle) {
        heightConstraint.flatMap { NSLayoutConstraint.deactivate([$0]) }

        let constraint = heightAnchor.constraint(equalToConstant: size.height)
        NSLayoutConstraint.activate([constraint])

        heightConstraint = constraint

        backgroundColor = style.backgroundColor
        layer.cornerRadius = style.cornerRadius
        layer.borderColor = style.borderColor.cgColor
        layer.borderWidth = style.borderWidth
        layer.masksToBounds = true
        titleLabel?.textColor = style.textColor
        titleLabel?.font = style.font
        setTitleColor(style.textColor, for: .normal)
        setTitleColor(style.textColorHighlighted, for: .highlighted)
        setBackgroundColor(style.backgroundColorHighlighted, forState: .highlighted)
        setBackgroundColor(style.backgroundColorHighlighted, forState: .selected)
        contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
    }
}
