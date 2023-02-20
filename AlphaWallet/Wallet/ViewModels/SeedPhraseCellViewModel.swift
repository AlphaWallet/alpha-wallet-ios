// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

struct SeedPhraseCellViewModel {
    let word: String
    let isSelected: Bool
    let index: Int?

    var backgroundColor: UIColor {
        return Configuration.Color.Semantic.seedPhraseCellBackground
    }

    var selectedBackgroundColor: UIColor {
        return Configuration.Color.Semantic.seedPhraseCellSelectedBackground
    }

    var textColor: UIColor {
        return Configuration.Color.Semantic.seedPhraseCellText
    }

    var selectedTextColor: UIColor {
        return Configuration.Color.Semantic.seedPhraseCellSelectedText
    }

    var font: UIFont {
        if ScreenChecker().isNarrowScreen {
            return Fonts.regular(size: 15)
        } else {
            return Fonts.regular(size: 18)
        }
    }

    var sequenceFont: UIFont {
        return Fonts.regular(size: 12)
    }

    var sequenceColor: UIColor {
        return Configuration.Color.Semantic.seedPhraseCellSequence
    }

    var sequence: String? {
        return index.flatMap { String(describing: $0 + 1) }
    }
}
