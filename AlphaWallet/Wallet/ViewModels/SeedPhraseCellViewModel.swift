// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

struct SeedPhraseCellViewModel {
    let word: String
    let isSelected: Bool
    let index: Int?

    var backgroundColor: UIColor {
        return Colors.clear
    }

    var selectedBackgroundColor: UIColor {
        return Colors.headerThemeColor
    }

    var textColor: UIColor {
        return Colors.headerThemeColor
    }

    var selectedTextColor: UIColor {
        return Colors.appWhite
    }

    var font: UIFont {
        if ScreenChecker().isNarrowScreen {
            return Fonts.semibold(size: 10)
        } else {
            return Fonts.semibold(size: 12)
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
