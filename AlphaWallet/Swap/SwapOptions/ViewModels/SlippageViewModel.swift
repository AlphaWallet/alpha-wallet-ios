//
//  SlippageViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import Foundation
import Combine

class SlippageViewModel {
    private (set) var selectedSlippage: CurrentValueSubject<SwapSlippage, Never>

    init(selectedSlippage: CurrentValueSubject<SwapSlippage, Never>) {
        self.selectedSlippage = selectedSlippage
    }

    lazy var initialSlippageValues: [SwapSlippage] = [.dotOne, .dotFive, .one, .custom(0.0)]
    lazy var availableSlippages: AnyPublisher<[SelectableSlippageViewModel], Never> = {
        return Just(initialSlippageValues)
            .combineLatest(selectedSlippage) { cases, selectedSlippage -> [SelectableSlippageViewModel] in
                return cases.map { .init(value: $0, isSelected: selectedSlippage == $0) }
            }.eraseToAnyPublisher()
    }()

    func set(slippage: SwapSlippage) {
        selectedSlippage.value = slippage
    }

    enum SwapSlippageViewType {
        case selectionButton
        case editingTextField
    }
}
