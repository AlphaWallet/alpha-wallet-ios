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
            let regex = try! NSRegularExpression(pattern: "^[0-9a-fA-F]{64}$")
            let range = NSRange(location: 0, length: drop0xKey.utf16.count)
            let result = regex.matches(in: drop0xKey, range: range)
            let matched = !result.isEmpty
            return matched ? nil : validationError
        }
        return value != nil ? nil : validationError
    }
}
