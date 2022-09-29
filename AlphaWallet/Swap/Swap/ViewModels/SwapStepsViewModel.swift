//
//  SwapStepsViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import UIKit
import Combine
import AlphaWalletFoundation

struct SwapStepsViewModelInput {

}

struct SwapStepsViewModelOutput {
    let areFeesHidden: AnyPublisher<Bool, Never>
    let swapStepsViewModels: AnyPublisher<[SwapStepsViewModel.SwapStepViewModel], Never>
}

final class SwapStepsViewModel {
    private let swapSteps: AnyPublisher<[SwapStep], Never>

    init(swapSteps: AnyPublisher<[SwapStep], Never>) {
        self.swapSteps = swapSteps
    }

    func transform(input: SwapStepsViewModelInput) -> SwapStepsViewModelOutput {
        let areFeesHidden = swapSteps.map { $0.isEmpty }
            .eraseToAnyPublisher()

        let swapStepsViewModels = swapSteps
                .map { $0.map { SwapStepsViewModel.SwapStepViewModel(swapStep: $0) } }
                .eraseToAnyPublisher()

        return .init(areFeesHidden: areFeesHidden, swapStepsViewModels: swapStepsViewModels)
    }
}
