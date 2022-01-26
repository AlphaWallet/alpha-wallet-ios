// Copyright SIX DAY LLC. All rights reserved.

import Foundation 

struct EthereumAddressValidator {
    private let validationError: ValidationError

    init(msg: String = R.string.localizable.importWalletImportInvalidAddress()) {
        validationError = ValidationError(msg: msg)
    }
    
    func isValid(value: String) -> ValidationError? {
        return !CryptoAddressValidator.isValidAddress(value) ? validationError : nil
    }
} 
