//
//  EditableSlippageViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import UIKit
import Combine

class EditableSlippageViewModel {
    var selectedSlippage: CurrentValueSubject<SwapSlippage, Never>

    lazy var shouldResignActive: AnyPublisher<Void, Never> = selectedSlippage
        .filter { $0.shouldResignActiveTextFieldWhenOtherSelected }
        .map { _ -> Void in return () }
        .eraseToAnyPublisher()

    var titleAttributedString: NSAttributedString {
        return .init(string: "Custom: ", attributes: [
            .font: Fonts.regular(size: 14),
            .foregroundColor: R.color.mine()!
        ])
    }

    var text: String? {
        return selectedSlippage.value
            .customValue
            .flatMap { String($0) }
    }

    var placeholderString: String { return "0.01%" }

    func slippage(text: AnyPublisher<String?, Never>) -> AnyPublisher<SwapSlippage, Never> {
        return text
            .compactMap { $0.flatMap { Double($0) } }
            .map { SwapSlippage.custom($0) }
            .eraseToAnyPublisher()
    }

    init(selectedSlippage: CurrentValueSubject<SwapSlippage, Never>) {
        self.selectedSlippage = selectedSlippage
    }

    func set(slippage: SwapSlippage) {
        selectedSlippage.value = slippage
    }

}
