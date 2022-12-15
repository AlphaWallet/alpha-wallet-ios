// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

struct VerifySeedPhraseViewModel {

    var title: String {
        return R.string.localizable.walletsVerifySeedPhraseTitle()
    }

    var seedPhraseTextViewBorderNormalColor: UIColor {
        return Configuration.Color.Semantic.seedText
    }

    var seedPhraseTextViewBorderErrorColor: UIColor {
        return Configuration.Color.Semantic.defaultErrorText
    }

    var seedPhraseTextViewBorderWidth: CGFloat {
        return 0.5
    }

    var seedPhraseTextViewBorderCornerRadius: CGFloat {
        return 7
    }

    var seedPhraseTextViewFont: UIFont {
        return Fonts.regular(size: 20)
    }

    var seedPhraseTextViewContentInset: UIEdgeInsets {
        return .init(top: 0, left: 7, bottom: 0, right: 7)
    }

    var errorColor: UIColor {
        return Configuration.Color.Semantic.defaultErrorText
    }

    //Make it the same as the background. Trick to maintain the height of the error label even when there's no error by putting some dummy text. The dummy text must still make sense for accessibility
    var noErrorColor: UIColor {
        return Configuration.Color.Semantic.defaultViewBackground
    }

    var errorFont: UIFont {
        return Fonts.regular(size: 18)
    }

    var noErrorText: String {
        //Don't need to localize. But still good to, for accessibility
        return "No error"
    }

    var importKeystoreJsonButtonFont: UIFont {
        return Fonts.regular(size: 20)
    }

    var subtitleColor: UIColor {
        return Configuration.Color.Semantic.defaultSubtitleText
    }

    var subtitleFont: UIFont {
        return Screen.Backup.subtitleFont
    }
}
