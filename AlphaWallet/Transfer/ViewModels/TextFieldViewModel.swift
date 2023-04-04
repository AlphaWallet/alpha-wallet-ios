//
//  TextFieldViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.08.2020.
//

import UIKit
import Combine

struct TextFieldViewModelInput {
    let textChanged: AnyPublisher<String?, Never>
}

struct TextFieldViewModelOuput {
    let text: AnyPublisher<String?, Never>
    let attributedPlaceholder: AnyPublisher<NSAttributedString?, Never>
    let keyboardType: AnyPublisher<UIKeyboardType, Never>
    let status: AnyPublisher<TextField.TextFieldErrorState, Never>
    let allowEditing: AnyPublisher<Bool, Never>
}

class TextFieldViewModel {
    private var cancellable = Set<AnyCancellable>()
    private let textChangedSubject = PassthroughSubject<String?, Never>()

    @Published private(set) var text: String?
    @Published var placeholder: String?
    @Published var keyboardType: UIKeyboardType = .default
    @Published var status: TextField.TextFieldErrorState = .none
    @Published var allowEditing: Bool = true

    init(text: String? = nil) {
        self.text = text
    }

    func set(text: String?) {
        textChangedSubject.send(text)
    }

    func transform(input: TextFieldViewModelInput) -> TextFieldViewModelOuput {
        input.textChanged
            .assign(to: \.text, on: self, ownership: .weak)
            .store(in: &cancellable)

        let placeholder = $placeholder.map { self.buildPlaceholder(string: $0) }

        return .init(
            text: textChangedSubject.prepend(text).eraseToAnyPublisher(),
            attributedPlaceholder: placeholder.eraseToAnyPublisher(),
            keyboardType: $keyboardType.eraseToAnyPublisher(),
            status: $status.eraseToAnyPublisher(),
            allowEditing: $allowEditing.eraseToAnyPublisher())
    }

    private func buildPlaceholder(string: String?) -> NSAttributedString? {
        guard let string = string, !string.trimmed.isEmpty else { return nil }

        return NSAttributedString(string: string, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText,
            .font: Fonts.regular(size: 13)
        ])
    }
}
