//
//  EditableSlippageViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import UIKit
import Combine
import AlphaWalletFoundation

struct EditableSlippageViewModelInput {
    let text: AnyPublisher<String?, Never>
}

struct EditableSlippageViewModelOutput {
    let shouldResignActive: AnyPublisher<Void, Never>
}

class EditableSlippageViewModel {
    private let selectedSlippage: CurrentValueSubject<SwapSlippage, Never>
    private var cancelable = Set<AnyCancellable>()

    var titleAttributedString: NSAttributedString {
        return .init(string: "Custom: ", attributes: [
            .font: Fonts.regular(size: 14),
            .foregroundColor: R.color.mine()!
        ])
    }

    var text: String? {
        return selectedSlippage.value
            .customValue
            .flatMap { String($0 * SwapSlippage.toPercentageUnits).droppedTrailingZeros }
    }

    var placeholderString: String { return "3%" }

    init(selectedSlippage: CurrentValueSubject<SwapSlippage, Never>) {
        self.selectedSlippage = selectedSlippage
    }

    func transform(input: EditableSlippageViewModelInput) -> EditableSlippageViewModelOutput {
        input.text
            .compactMap { $0.flatMap { Double($0) } }
            .map { SwapSlippage.custom(from: $0) }
            .assign(to: \.value, on: selectedSlippage, ownership: .weak)
            .store(in: &cancelable)

        let shouldResignActive: AnyPublisher<Void, Never> = selectedSlippage
            .filter { $0.shouldResignActiveTextFieldWhenOtherSelected }
            .mapToVoid()
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        return .init(shouldResignActive: shouldResignActive)
    }

}
