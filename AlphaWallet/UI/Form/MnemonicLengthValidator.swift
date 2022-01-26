// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import WalletCore

struct MnemonicLengthValidator {

    private let validationError: ValidationError

    init() {
        var msg: String
        if Features.is24SeedWordPhraseAllowed {
            msg = R.string.localizable.importWalletImportInvalidMnemonicCount24()
        } else {
            msg = R.string.localizable.importWalletImportInvalidMnemonicCount12()
        }
        validationError = ValidationError(msg: msg)
    }

    func isValid(value: String) -> ValidationError? {
        let words = value.trimmed.split(separator: " ")
        return !isValidSeedPhraseLength(count: words.count) ? validationError : nil
    }

    func isValidSeedPhraseLength(count: Int) -> Bool {
        if Features.is24SeedWordPhraseAllowed {
            return HDWallet.validSeedPhraseCounts.contains(count)
        }
        return count == HDWallet.SeedPhraseCount.word12.count
    }
}
