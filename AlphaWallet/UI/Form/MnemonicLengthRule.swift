// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import Eureka
import WalletCore

struct MnemonicLengthRule<T: Equatable>: RuleType {
    public init() {
        self.validationError = ValidationError(msg: R.string.localizable.importWalletImportInvalidMnemonicCount())
    }

    public var id: String?
    public var validationError: ValidationError

    public func isValid(value: T?) -> ValidationError? {
        if let str = value as? String {
            let words = str.trimmed.split(separator: " ")
            return (words.count != HDWallet.mnemonicWordCount) ? validationError : nil
        }
        return value != nil ? nil : validationError
    }
}
