// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

struct VerifySeedPhraseViewModel {
    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var title: String {
        return R.string.localizable.walletsVerifySeedPhraseTitle()
    }

    var seedPhraseTextViewBorderNormalColor: UIColor {
        return Colors.lightGray
    }

    var seedPhraseTextViewBorderErrorColor: UIColor {
        return Colors.appRed
    }

    var seedPhraseTextViewBorderWidth: CGFloat {
        return 0.5
    }

    var seedPhraseTextViewBorderCornerRadius: CGFloat {
        return 7
    }

    var seedPhraseTextViewFont: UIFont {
        return Fonts.regular(size: 20)!
    }

    var seedPhraseTextViewContentInset: UIEdgeInsets {
        return .init(top: 0, left: 7, bottom: 0, right: 7)
    }

    var errorColor: UIColor {
        return Colors.appRed
    }

    var errorFont: UIFont {
        return Fonts.regular(size: 18)!
    }
}
