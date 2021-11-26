// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

struct ShowSeedPhraseViewModel {
    private let error: KeystoreError?

    var words: [String]

    var subtitle: String = R.string.localizable.walletsShowSeedPhraseSubtitle()
    var buttonTitle: String = R.string.localizable.walletsShowSeedPhraseTestSeedPhrase()
    
    var subtitleColor: UIColor {
        return Colors.headerThemeColor
    }

    var subtitleFont: UIFont {
        return Screen.Backup.WalletHeaderValue
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
