// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

struct ShowSeedPhraseViewModel {
    private let error: KeystoreError?

    let words: [String]

    var subtitle: String = R.string.localizable.walletsShowSeedPhraseSubtitle()
    var buttonTitle: String = R.string.localizable.walletsShowSeedPhraseTestSeedPhrase()
    
    var subtitleColor: UIColor {
        return Configuration.Color.Semantic.defaultSubtitleText
    }

    var subtitleFont: UIFont {
        return Screen.Backup.subtitleFont
    }

    var errorColor: UIColor {
        return Configuration.Color.Semantic.defaultErrorText
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
