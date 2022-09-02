//
//  SwapStepsViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import UIKit
import Combine
import AlphaWalletFoundation

class SwapStepsViewModel {
    private let swapSteps: AnyPublisher<[SwapStep], Never>

    init(swapSteps: AnyPublisher<[SwapStep], Never>) {
        self.swapSteps = swapSteps
    }

    var hasProviders: AnyPublisher<Bool, Never> {
        swapSteps.map { !$0.isEmpty }
            .eraseToAnyPublisher()
    }

    var swapStepsViewModels: AnyPublisher<[SwapStepsViewModel.SwapStepViewModel], Never> {
        swapSteps
            .map { $0.map { SwapStepsViewModel.SwapStepViewModel(swapStep: $0) } }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}
