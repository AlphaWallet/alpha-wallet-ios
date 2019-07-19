// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

struct ShowSeedPhraseViewModel {
    private let error: KeystoreError?

    let words: [String]

    var title: String {
        return R.string.localizable.walletsShowSeedPhraseTitle()
    }

    var subtitle: String {
        return R.string.localizable.walletsShowSeedPhraseSubtitle()
    }

    var subtitleColor: UIColor {
        return Colors.darkGray
    }

    var subtitleFont: UIFont {
        return Fonts.regular(size: 18)!
    }

    var description: String {
        return R.string.localizable.walletsShowSeedPhraseDescription()
    }

    var descriptionColor: UIColor {
        return Colors.darkGray
    }

    var descriptionFont: UIFont {
        return Fonts.regular(size: 18)!
    }

    var errorColor: UIColor {
        return Colors.appRed
    }

    var errorFont: UIFont {
        return Fonts.regular(size: 18)!
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
