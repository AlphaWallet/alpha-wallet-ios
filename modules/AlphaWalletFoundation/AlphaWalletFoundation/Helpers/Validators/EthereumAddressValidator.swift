// Copyright SIX DAY LLC. All rights reserved.

import Foundation

import struct AlphaWalletCore.CryptoAddressValidator
typealias CryptoAddressValidator = AlphaWalletCore.CryptoAddressValidator

public struct EthereumAddressValidator {
    private let validationError: ValidationError

    public init(msg: String) {
        validationError = ValidationError(msg: msg)
    }

    public func isValid(value: String) -> ValidationError? {
        return !CryptoAddressValidator.isValidAddress(value) ? validationError : nil
    }
}
