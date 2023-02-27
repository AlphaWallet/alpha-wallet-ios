//
//  EnterAssetAmountViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.02.2023.
//

import UIKit
import Combine

struct EnterAssetAmountViewModelInput {

}

struct EnterAssetAmountViewModelOutput {
    let activate: AnyPublisher<Void, Never>
    let close: AnyPublisher<Void, Never>
}

class EnterAssetAmountViewModel {
    private let activateSelectionSubject = PassthroughSubject<Void, Never>()
    let selectAssetViewModel: EditableSelectAssetAmountViewModel

    var selected: AnyPublisher<Int, Never> {
        selectAssetViewModel.selectionViewModel.selected
    }

    var close: AnyPublisher<Void, Never> {
        selectAssetViewModel.close
    }

    init(available: Int = 0, selected: Int = 0) {
        selectAssetViewModel = .init(available: available, selected: selected)
    }

    func transform(input: EnterAssetAmountViewModelInput) -> EnterAssetAmountViewModelOutput {
        return .init(
            activate: activateSelectionSubject.eraseToAnyPublisher(),
            close: selectAssetViewModel.close)
    }

    func activateSelection() {
        activateSelectionSubject.send(())
    }
}
