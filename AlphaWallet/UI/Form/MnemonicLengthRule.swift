// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import Eureka
import WalletCore

struct MnemonicLengthRule<T: Equatable>: RuleType {
    public init() {
        let msg = Features.is24SeedWordPhraseAllowed ? R.string.localizable.importWalletImportInvalidMnemonicCount24() : R.string.localizable.importWalletImportInvalidMnemonicCount12()
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
        return Features.is24SeedWordPhraseAllowed ? count == 12 || count == 24 : count == 12
    }
}
