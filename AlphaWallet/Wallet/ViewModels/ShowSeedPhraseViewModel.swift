// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

struct ShowSeedPhraseViewModel {
    private let error: KeystoreError?

    let words: [String]

    var subtitle: String = R.string.localizable.walletsShowSeedPhraseSubtitle(preferredLanguages: Languages.preferred())
    var buttonTitle: String = R.string.localizable.walletsShowSeedPhraseTestSeedPhrase(preferredLanguages: Languages.preferred())
    
    var subtitleColor: UIColor {
        return Screen.Backup.subtitleColor
    }

    var subtitleFont: UIFont {
        return Screen.Backup.subtitleFont
    }

    var errorColor: UIColor {
        return Colors.appRed
    }

    var errorFont: UIFont {
        return Fonts.regular(size: 18)
    }

    var errorMessage: String? {
        return error?.errorDescription
    }

    init(words: [String]) {
        self.words = words
        self.error = nil
    }

    init(error: KeystoreError) {
        self.words = []
        self.error = error
    }
}
