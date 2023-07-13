// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import AlphaWalletTrustWalletCoreExtensions

public struct MnemonicLengthValidator {

    private let validationError: ValidationError

    public init(message: String) {
        validationError = ValidationError(msg: message)
    }

    public func isValid(value: String) -> ValidationError? {
        let words = value.trimmed.split(separator: " ")
        return !isValidSeedPhraseLength(count: words.count) ? validationError : nil
    }

    public func isValidSeedPhraseLength(count: Int) -> Bool {
        if Features.current.isAvailable(.is24SeedWordPhraseAllowed) {
            return HDWallet.validSeedPhraseCounts.contains(count)
        }
        return count == HDWallet.SeedPhraseCount.word12.count
    }
}
