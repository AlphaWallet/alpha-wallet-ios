// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import Eureka
import TrustWalletCore

struct MnemonicRule<T: Equatable>: RuleType {
    public init(msg: String = "") {
        let msg = msg.isEmpty ? R.string.localizable.importWalletImportInvalidMnemonic() : msg
        self.validationError = ValidationError(msg: msg)
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
