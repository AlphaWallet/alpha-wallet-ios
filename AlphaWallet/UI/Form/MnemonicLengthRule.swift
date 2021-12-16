// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import Eureka
import WalletCore

struct MnemonicLengthRule<T: Equatable>: RuleType {
    public init() {
        var msg: String
        if Features.is24SeedWordPhraseAllowed {
            msg = R.string.localizable.importWalletImportInvalidMnemonicCount24()
        } else {
            msg = R.string.localizable.importWalletImportInvalidMnemonicCount12()
        }
        self.validationError = ValidationError(msg: msg)
    }

    public var id: String?
    public var validationError: ValidationError

    public func isValid(value: T?) -> ValidationError? {
        if let str = value as? String {
            let words = str.trimmed.split(separator: " ")
            return !isValidSeedPhraseLength(count: words.count) ? validationError : nil
        }
        return value != nil ? nil : validationError
    }

    private func isValidSeedPhraseLength(count: Int) -> Bool {
        if Features.is24SeedWordPhraseAllowed {
            return HDWallet.validSeedPhraseCounts.contains(count)
        }
        return count == HDWallet.SeedPhraseCount.word12.count
    }
}
