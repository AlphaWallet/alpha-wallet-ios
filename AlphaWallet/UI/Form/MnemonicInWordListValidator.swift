// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import WalletCore

struct MnemonicInWordListValidator {

    private let validationError: ValidationError

    init(msg: String = R.string.localizable.importWalletImportInvalidMnemonic()) {
        validationError = ValidationError(msg: msg)
    }

    func isValid(value: String) -> ValidationError? {
        let words = value.trimmed.split(separator: " ")
        return words.allSatisfy({ HDWallet.isWordInWordList(String($0)) }) ? nil : validationError
    }
}
