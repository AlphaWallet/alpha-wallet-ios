// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import Eureka
import WalletCore

struct MnemonicInWordListRule<T: Equatable>: RuleType {
    public init() {
        self.validationError = ValidationError(msg: R.string.localizable.importWalletImportInvalidMnemonic())
    }

    public var id: String?
    public var validationError: ValidationError

    public func isValid(value: T?) -> ValidationError? {
        if let str = value as? String {
            let words = str.trimmed.split(separator: " ")
            return words.allSatisfy({ HDWallet.isWordInWordList(String($0)) }) ? nil : validationError
        }
        return value != nil ? nil : validationError
    }
}
