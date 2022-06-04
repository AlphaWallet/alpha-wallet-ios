//
//  SwapFeesViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import UIKit
import Combine

class SwapFeesViewModel: ObservableObject {
    @Published private var providers: [SwapProvider]

    init(providers: [SwapProvider] ) {
        self.providers = providers
    }

    var hasProviders: AnyPublisher<Bool, Never> {
        $providers.map { !$0.isEmpty }
            .eraseToAnyPublisher()
    }

    var providersViewModels: AnyPublisher<[SwapFeesViewModel.SwapFeeProviderViewModel], Never> {
        $providers
            .map { $0.map { SwapFeesViewModel.SwapFeeProviderViewModel(provider: $0) } }
            .eraseToAnyPublisher()
    }
}
