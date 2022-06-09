//
//  SwapFeeProviderViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import UIKit
import Combine

extension SwapFeesViewModel {
    struct SwapFeeProviderViewModel {
        private let provider: SwapProvider

        var backgroundColor: UIColor = R.color.alabaster()!

        var nameAttributedString: AnyPublisher<NSAttributedString, Never> {
            provider.name.map {
                NSAttributedString(string: $0, attributes: [
                    .font: Fonts.regular(size: 15),
                    .foregroundColor: R.color.dove()!
                ])
            }.eraseToAnyPublisher()
        }

        var feeAttributedString: AnyPublisher<NSAttributedString, Never> {
            provider.fee.map {
                NSAttributedString(string: $0, attributes: [
                    .font: Fonts.regular(size: 17),
                    .foregroundColor: Colors.black
                ])
            }.eraseToAnyPublisher()
        }

        init(provider: SwapProvider) {
            self.provider = provider
        }
    }
}
