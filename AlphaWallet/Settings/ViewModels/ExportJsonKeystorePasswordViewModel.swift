//
//  ExportJsonKeystorePasswordViewModel.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 2/12/21.
//

import Foundation
import AlphaWalletFoundation

class ExportJsonKeystorePasswordViewModel {
    private let validator: StringValidator

    init() {
        self.validator = StringValidator(rules: [
            .lengthMoreThanOrEqualTo(6),
            .canOnlyContain(CharacterSet.alphanumerics)
        ])
    }

    init(validator: StringValidator) {
        self.validator = validator
    }

    func validate(password: String) -> StringValidatorResult {
        return validator.validate(string: password)
    }

    func containsIllegalCharacters(password: String) -> Bool {
        return validator.containsIllegalCharacters(string: password)
    }
}
