//
//  ExportJsonKeystorePasswordViewModel.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 2/12/21.
//

import Foundation

class ExportJsonKeystorePasswordViewModel {
    private let validator: StringValidator
    private let keystore: Keystore

    init(keystore: Keystore) {
        self.validator = StringValidator(rules: [
            .lengthMoreThanOrEqualTo(6),
            .canOnlyContain(CharacterSet.alphanumerics)
        ])
        self.keystore = keystore
    }

    init(keystore: Keystore, validator: StringValidator) {
        self.validator = validator
        self.keystore = keystore
    }

    func validate(password: String) -> StringValidatorResult {
        return validator.validate(string: password)
    }

    func containsIllegalCharacters(password: String) -> Bool {
        return validator.containsIllegalCharacters(string: password)
    }
}
