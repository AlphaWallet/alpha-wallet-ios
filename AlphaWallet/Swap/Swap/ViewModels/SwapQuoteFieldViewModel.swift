//
//  SwapQuoteFieldViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import UIKit
import Combine

struct SwapQuoteFieldViewModelInput {

}

struct SwapQuoteFieldViewModelOutput {
    let value: AnyPublisher<NSAttributedString?, Never>
    let isHidden: AnyPublisher<Bool, Never>
}

final class SwapQuoteFieldViewModel {
    private let isHidden: AnyPublisher<Bool, Never>
    private let value: AnyPublisher<String, Never>
    var titleAttributedString: NSAttributedString {
        NSAttributedString(string: title, attributes: [
            .font: Fonts.regular(size: 15),
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText
        ])
    }

    private let title: String

    init(title: String, value: AnyPublisher<String, Never>, isHidden: AnyPublisher<Bool, Never> = .just(false)) {
        self.title = title
        self.value = value
        self.isHidden = isHidden
    }

    func transform(input: SwapQuoteFieldViewModelInput) -> SwapQuoteFieldViewModelOutput {
        let value = value.map { value -> NSAttributedString? in
            return NSAttributedString(string: value.replacingOccurrences(of: "\0", with: ""), attributes: [
                .font: Fonts.regular(size: 17),
                .foregroundColor: Configuration.Color.Semantic.defaultForegroundText
            ])
        }.eraseToAnyPublisher()

        return .init(value: value, isHidden: isHidden)
    }
}
