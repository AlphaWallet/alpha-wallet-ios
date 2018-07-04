// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Eureka

public struct PrivateKeyRule<T: Equatable>: RuleType {

    public init(msg: String = "") {
        let msg = msg.isEmpty ? R.string.localizable.importWalletImportInvalidPrivateKey() : msg
        self.validationError = ValidationError(msg: msg)
    }

    public var id: String?
    public var validationError: ValidationError

    public func isValid(value: T?) -> ValidationError? {
        if let str = value as? String {
            //allows for private key import to have 0x or not
            let drop0xKey = str.drop0x
            return (drop0xKey.count != 64) ? validationError : nil
        }
        return value != nil ? nil : validationError
    }
}
