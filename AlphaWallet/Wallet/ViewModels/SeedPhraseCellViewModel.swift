// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

struct SeedPhraseCellViewModel {
    let word: String
    let isSelected: Bool
    let index: Int?

    var backgroundColor: UIColor {
        return UIColor(red: 234, green: 234, blue: 234)
    }

    var selectedBackgroundColor: UIColor {
        return UIColor(red: 249, green: 249, blue: 249)
    }

    var textColor: UIColor {
        return Colors.headerThemeColor
    }

    var selectedTextColor: UIColor {
        return Colors.headerThemeColor
    }

    var font: UIFont {
        if ScreenChecker().isNarrowScreen {
            return Fonts.semibold(size: 9)
        } else {
            return Fonts.semibold(size: 9)
        }
    }

    var sequenceFont: UIFont {
        return Fonts.regular(size: 12)
    }

    var sequenceColor: UIColor {
        return UIColor(red: 200, green: 200, blue: 200)
    }

    var sequence: String? {
        return index.flatMap { String(describing: $0 + 1) }
    }
}
