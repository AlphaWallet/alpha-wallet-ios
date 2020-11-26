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

enum ButtonStyle: Int {
    case solid
    case squared
    case border
    case borderless
    case system

    var backgroundColor: UIColor {
        switch self {
        case .solid, .squared: return Colors.appTint
        case .border, .borderless: return .white
        case .system: return .clear
        }
    }

    var backgroundColorHighlighted: UIColor {
        switch self {
        case .solid, .squared: return Colors.appTint
        case .border: return Colors.appTint
        case .borderless: return .white
        case .system: return .clear
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .solid, .border: return 5
        case .squared, .borderless, .system: return 0
        }
    }

    var font: UIFont {
        switch self {
        case .solid,
             .squared,
             .border,
             .borderless, .system:
            return Fonts.semibold(size: 16)
        }
    }

    var textColor: UIColor {
        switch self {
        case .solid, .squared: return Colors.appWhite
        case .border, .borderless, .system: return Colors.appTint
        }
    }

    var textColorHighlighted: UIColor {
        switch self {
        case .solid, .squared: return UIColor(white: 1, alpha: 0.8)
        case .border: return Colors.appWhite
        case .borderless, .system: return Colors.appTint
        }
    }

    var borderColor: UIColor {
        switch self {
        case .solid, .squared, .border: return GroupedTable.Color.background
        case .borderless, .system: return .clear
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .solid, .squared, .borderless, .system: return 0
        case .border: return 1
        }
    }
}

class Button: UIButton {

    init(size: ButtonSize, style: ButtonStyle) {
        super.init(frame: .zero)
        apply(size: size, style: style)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(size: ButtonSize, style: ButtonStyle) {
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: size.height),
            ])

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
