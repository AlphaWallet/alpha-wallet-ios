// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

struct PassphraseViewModel {

    var title: String {
        return R.string.localizable.recoveryPhraseNavigationTitle()
    }

    var backgroundColor: UIColor {
        return .white
    }

    var rememberPassphraseText: String {
        return R.string.localizable.passphraseRememberLabelTitle()
    }

    var phraseFont: UIFont {
        return Fonts.semibold(size: 16)!
    }
}
