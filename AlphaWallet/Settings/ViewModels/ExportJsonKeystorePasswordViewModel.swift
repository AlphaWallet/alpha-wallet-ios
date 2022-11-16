//
//  ExportJsonKeystorePasswordViewModel.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 2/12/21.
//

import Foundation
import AlphaWalletFoundation
import Combine

struct ExportJsonKeystorePasswordViewModelInput {
    let text: AnyPublisher<String?, Never>
    let exportJson: AnyPublisher<Void, Never>
}

struct ExportJsonKeystorePasswordViewModelOutput {
    let viewState: AnyPublisher<ExportJsonKeystorePasswordViewModel.ViewState, Never>
    let validatedPassword: AnyPublisher<String, Never>
}

class ExportJsonKeystorePasswordViewModel {
    private var password: String = ""
    private let validator = StringValidator(rules: [
        .lengthMoreThanOrEqualTo(6),
    ])

    func transform(input: ExportJsonKeystorePasswordViewModelInput) -> ExportJsonKeystorePasswordViewModelOutput {
        let isPasswordValid = input.text
            .compactMap { $0 }
            .map {
                switch self.validate(password: $0) {
                case .success:
                    self.password = $0
                    return true
                case .failure:
                    return false
                }
            }

        let validatedPassword = input.exportJson
            .map { _ in self.password }
            .eraseToAnyPublisher()

        let exportJsonButtonEnabled = Publishers.Merge(Just(false), isPasswordValid)

        let viewState = exportJsonButtonEnabled
            .map { ExportJsonKeystorePasswordViewModel.ViewState(exportJsonButtonEnabled: $0) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState, validatedPassword: validatedPassword)
    }

    func shouldChangeCharacters(text: String, replacementString string: String, in range: NSRange) -> TextChangeEvent {
        var currentPasswordString = text
        guard let stringRange = Range(range, in: currentPasswordString) else { return (nil, true) }
        let originalPasswordString = currentPasswordString
        currentPasswordString.replaceSubrange(stringRange, with: string)

        let validPassword = !containsIllegalCharacters(password: currentPasswordString)

        return (validPassword ? currentPasswordString: originalPasswordString, validPassword)
    }

    private func validate(password: String) -> StringValidatorResult {
        return validator.validate(string: password)
    }

    private func containsIllegalCharacters(password: String) -> Bool {
        return validator.containsIllegalCharacters(string: password)
    }
}

extension ExportJsonKeystorePasswordViewModel {
    typealias TextChangeEvent = (text: String?, shouldChangeCharacters: Bool)

    struct ViewState {
        let buttonTitle: String = R.string.localizable.settingsAdvancedExportJSONKeystorePasswordPasswordButtonPassword()
        let title: String = R.string.localizable.settingsAdvancedExportJSONKeystorePasswordTitle()
        let exportJsonButtonEnabled: Bool
    }
}
