//
//  EnterKeystorePasswordViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.01.2022.
//

import Foundation
import AlphaWalletFoundation

class EnterKeystorePasswordViewModel {
    var validator: StringValidator = StringValidator(rules: [
        .lengthMoreThanOrEqualTo(6),
        .canOnlyContain(CharacterSet.alphanumerics)
    ])
    var buttonTitle: String = R.string.localizable.save()

    var navigationTitle: String {
        //Have to use the short version otherwise the next screen's back button might be distorted
        return R.string.localizable.enterPasswordNavigationTitleShorter()
    }

    var headerSectionText: String {
        return R.string.localizable.enterPasswordPasswordHeaderPlaceholder()
    }

    var passwordFieldPlaceholder: String {
        if ScreenChecker().isNarrowScreen {
            return R.string.localizable.enterPasswordPasswordTextFieldPlaceholderShorter()
        } else {
            return R.string.localizable.enterPasswordPasswordTextFieldPlaceholder()
        }
    }

    func validate(password: String) -> StringValidatorResult {
        return validator.validate(string: password)
    }

    func containsIllegalCharacters(password: String) -> Bool {
        return validator.containsIllegalCharacters(string: password)
    }
}
