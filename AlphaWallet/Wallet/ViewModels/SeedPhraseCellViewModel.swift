// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

struct SeedPhraseCellViewModel {
    let word: String
    let isSelected: Bool

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
}
