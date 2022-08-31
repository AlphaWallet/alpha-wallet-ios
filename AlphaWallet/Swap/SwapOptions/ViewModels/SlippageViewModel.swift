//
//  SlippageViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import Foundation
import Combine
import AlphaWalletFoundation

struct SlippageViewModelInput { }

struct SlippageViewModelOutput {
    let views: AnyPublisher<[SwapSlippage], Never>
    let availableSlippages: AnyPublisher<[SelectableSlippageViewModel], Never>
}

class SlippageViewModel {
    let selectedSlippage: CurrentValueSubject<SwapSlippage, Never>

    init(selectedSlippage: CurrentValueSubject<SwapSlippage, Never>) {
        self.selectedSlippage = selectedSlippage
    }

    func transform(input: SlippageViewModelInput) -> SlippageViewModelOutput {
        let views: AnyPublisher<[SwapSlippage], Never> = .just(SwapSlippage.allCases)

        let availableSlippages = views.combineLatest(selectedSlippage) { cases, selectedSlippage -> [SelectableSlippageViewModel] in
            var cases = cases
            switch selectedSlippage {
            case .custom:
                if let index = cases.firstIndex(where: { slip in guard case .custom = slip else { return false }; return true; }) {
                    cases[index] = selectedSlippage
                }
            case .onePercents, .fivePercents, .tenPercents:
                break
            }
            return cases.map { .init(value: $0, isSelected: selectedSlippage == $0) }
        }.receive(on: RunLoop.main)
        .eraseToAnyPublisher()

        return .init(views: views, availableSlippages: availableSlippages)
    }

    func set(slippage: SwapSlippage) {
        selectedSlippage.value = slippage
    }

    enum SwapSlippageViewType {
        case selectionButton
        case editingTextField
    }
}

extension SwapSlippage {
    var viewType: SlippageViewModel.SwapSlippageViewType {
        switch self {
        case .onePercents, .fivePercents, .tenPercents: return .selectionButton
        case .custom: return .editingTextField
        }
    }
}
