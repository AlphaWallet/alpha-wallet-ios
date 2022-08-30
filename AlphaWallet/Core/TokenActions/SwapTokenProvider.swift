//
//  SwapTokenProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.08.2022.
//

import Foundation
import Combine

final class SwapTokenProvider: SupportedTokenActionsProvider, TokenActionProvider, TokenActionServiceProvidable {
    private let subProviders: [SupportedTokenActionsProvider & TokenActionProvider]

    var objectWillChange: AnyPublisher<Void, Never> {
        return Just(subProviders)
            .flatMap { Publishers.MergeMany($0.map { $0.objectWillChange }) }
            .mapToVoid()
            .eraseToAnyPublisher()
    }

    let analyticsNavigation: Analytics.Navigation = .fallback
    let analyticsName: String = "Swap"
    let action: String
    var services: [SupportedTokenActionsProvider & TokenActionProvider] { return subProviders }

    func isSupport(token: TokenActionsIdentifiable) -> Bool {
        return subProviders.contains(where: { $0.isSupport(token: token) })
    }

    func service(ofType: SupportedTokenActionsProvider.Type) -> SupportedTokenActionsProvider? {
        return subProviders.first(where: { type(of: $0) == ofType })
    }

    func actions(token: TokenActionsIdentifiable) -> [TokenInstanceAction] {
        return [.init(type: .swap(service: self))]
    }

    init(subProviders: [SupportedTokenActionsProvider & TokenActionProvider], action: String) {
        self.subProviders = subProviders
        self.action = action
    }

    func start() {
        subProviders.forEach { $0.start() }
    }
}
