//
//  UpdateInViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.04.2023.
//

import Foundation
import Combine
import AlphaWalletFoundation

struct UpdateInViewModelInput {

}

struct UpdateInViewModelOutput {
    let text: AnyPublisher<NSAttributedString?, Never>
    let timerText: AnyPublisher<NSAttributedString?, Never>
    let isLoadingHidden: AnyPublisher<Bool, Never>
}

class UpdateInViewModel {
    private let gasPriceEstimator: GasPriceEstimator

    init(gasPriceEstimator: GasPriceEstimator) {
        self.gasPriceEstimator = gasPriceEstimator
    }

    func transform(input: UpdateInViewModelInput) -> UpdateInViewModelOutput {
        let timerText = gasPriceEstimator.state
            .map { state -> String? in
                switch state {
                case .idle, .done, .loading: return nil
                case .tick(let int): return String(int)
                }
            }.removeDuplicates()
            .map { self.buildTimerString($0) }

        let isLoadingHidden = gasPriceEstimator.state
            .map { state -> Bool in
                switch state {
                case .tick, .idle, .done: return true
                case .loading: return false
                }
            }.removeDuplicates()

        return .init(
            text: Just(buildTitleString(R.string.localizable.configureTransactionHeaderNextUpdateIn())).eraseToAnyPublisher(),
            timerText: timerText.eraseToAnyPublisher(),
            isLoadingHidden: isLoadingHidden.eraseToAnyPublisher())
    }

    private func buildTimerString(_ value: String?) -> NSAttributedString? {
        guard let value = value else { return nil }
        return NSAttributedString(string: value, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText,
            .font: Fonts.semibold(size: 14)
        ])
    }

    private func buildTitleString(_ value: String?) -> NSAttributedString? {
        guard let value = value else { return nil }
        return NSAttributedString(string: value, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText,
            .font: Fonts.regular(size: 14)
        ])
    }
}
