//
//  EditableSelectAssetAmountViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.02.2023.
//

import UIKit
import Combine

struct EditableSelectAssetAmountViewModelInput {
    let text: AnyPublisher<String, Never>
    let close: AnyPublisher<Void, Never>
}

struct EditableSelectAssetAmountViewModelOutput {
    let title: AnyPublisher<NSAttributedString, Never>
}

class EditableSelectAssetAmountViewModel {
    private var cancellable = Set<AnyCancellable>()
    private let closeSubject = PassthroughSubject<Void, Never>()
    private let available: Int

    let selectionViewModel: SelectAssetViewModel
    var close: AnyPublisher<Void, Never> {
        closeSubject.eraseToAnyPublisher()
    }

    init(available: Int = 0, selected: Int = 0) {
        self.available = available
        selectionViewModel = SelectAssetViewModel(available: available, selected: selected)
    }

    func transform(input: EditableSelectAssetAmountViewModelInput) -> EditableSelectAssetAmountViewModelOutput {
        input.close
            .multicast(subject: closeSubject)
            .connect()
            .store(in: &cancellable)

        input.text
            .sink { [selectionViewModel] in selectionViewModel.set(counter: $0) }
            .store(in: &cancellable)

        let title = selectionViewModel.selected
            .map { _ in self.buildAttributedString() }

        return .init(title: title.eraseToAnyPublisher())
    }

    private func buildAttributedString() -> NSAttributedString {
        return .init(string: "Select Amount (max. \(available))", attributes: [
            .font: Fonts.semibold(size: 17),
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText
        ])
    }
}
