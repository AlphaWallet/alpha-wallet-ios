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
        return UIColor(red: 87, green: 87, blue: 87)
    }

    var selectedTextColor: UIColor {
        return UIColor(red: 255, green: 255, blue: 255)
    }

    var font: UIFont {
        if ScreenChecker().isNarrowScreen {
            return Fonts.regular(size: 15)!
        } else {
            return Fonts.regular(size: 18)!
        }
    }

    var sequenceFont: UIFont {
        return Fonts.regular(size: 12)!
    }

    var sequenceColor: UIColor {
        return UIColor(red: 200, green: 200, blue: 200)
    }

    var sequence: String? {
        return index.flatMap { String(describing: $0 + 1) }
    }
}
