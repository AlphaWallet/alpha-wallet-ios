// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Eureka

public struct EthereumAddressRule<T: Equatable>: RuleType {

    public init(msg: String = "") {
        let msg = msg.isEmpty ? R.string.localizable.importWalletImportInvalidAddress() : msg
        self.validationError = ValidationError(msg: msg)
    }

    public var id: String?
    public var validationError: ValidationError

    public func isValid(value: T?) -> ValidationError? {
        if let str = value as? String {
            return !CryptoAddressValidator.isValidAddress(str) ? validationError : nil
        }
        return value != nil ? nil : validationError
    }
}
