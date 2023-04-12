//
//  ConfirmButtonViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.03.2023.
//

import Foundation
import UIKit
import Combine
import AlphaWalletFoundation

struct ConfirmButtonViewModelInput {
    let trigger: AnyPublisher<Void, Never>
}

struct ConfirmButtonViewModelOutput {
    //NOTE: crucial to make sure view model don't have any delay to return data on initial call, delaying might brake view appearing animation,
    //make sure view models have `.initial` value
    let viewState: AnyPublisher<ConfirmButtonViewModel.ViewState, Never>
    let confirmSelected: AnyPublisher<Void, Never>
}

class ConfirmButtonViewModel {
    @Published private var isButtonEnabled: Bool = true
    private let title: String
    private let configurator: TransactionConfigurator
    private var cancellable = Set<AnyCancellable>()

    init(configurator: TransactionConfigurator, title: String) {
        self.configurator = configurator
        self.title = title
        
        //NOTE: prev impl wanted some delay after changing transaction configuration
        Publishers.Merge(configurator.$gasLimit.mapToVoid(), configurator.gasPriceEstimator.gasPricePublisher.mapToVoid())
            .handleEvents(receiveOutput: { [weak self] _ in self?.isButtonEnabled = false })
            .delay(for: .milliseconds(300), scheduler: RunLoop.main)
            .handleEvents(receiveOutput: { [weak self] _ in self?.isButtonEnabled = true })
            .sink { _ in }
            .store(in: &cancellable)
    }

    func transform(input: ConfirmButtonViewModelInput) -> ConfirmButtonViewModelOutput {
        let confirmSelected = input.trigger
            .filter { _ in self.isButtonEnabled }

        let viewState = $isButtonEnabled
            .map { [title] in ConfirmButtonViewModel.ViewState(title: title, isEnabled: $0) }

        return .init(
            viewState: viewState.eraseToAnyPublisher(),
            confirmSelected: confirmSelected.eraseToAnyPublisher())
    }
}

extension ConfirmButtonViewModel {
    struct ViewState {
        let title: String
        let isEnabled: Bool
    }
}
