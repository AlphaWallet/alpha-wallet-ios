// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import WalletCore

public struct MnemonicInWordListValidator {

    private let validationError: ValidationError

    public init(msg: String) {
        validationError = ValidationError(msg: msg)
    }

    public func isValid(value: String) -> ValidationError? {
        let words = value.trimmed.split(separator: " ")
        return words.allSatisfy({ HDWallet.isWordInWordList(String($0)) }) ? nil : validationError
    }
}
