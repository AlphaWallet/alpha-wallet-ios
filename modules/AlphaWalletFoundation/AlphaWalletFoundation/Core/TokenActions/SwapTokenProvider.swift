//
//  SwapTokenProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.08.2022.
//

import Foundation
import Combine

public final class SwapTokenProvider: SupportedTokenActionsProvider, TokenActionProvider, TokenActionServiceProvidable {
    private let subProviders: [SupportedTokenActionsProvider & TokenActionProvider]

    public var objectWillChange: AnyPublisher<Void, Never> {
        return Just(subProviders)
            .flatMap { Publishers.MergeMany($0.map { $0.objectWillChange }) }
            .mapToVoid()
            .eraseToAnyPublisher()
    }

    public let analyticsNavigation: Analytics.Navigation = .fallback
    public let analyticsName: String = "Swap"
    public let action: String
    public var services: [SupportedTokenActionsProvider & TokenActionProvider] { return subProviders }

    public func isSupport(token: TokenActionsIdentifiable) -> Bool {
        return subProviders.contains(where: { $0.isSupport(token: token) })
    }

    public func service(ofType: SupportedTokenActionsProvider.Type) -> SupportedTokenActionsProvider? {
        return subProviders.first(where: { type(of: $0) == ofType })
    }

    public func actions(token: TokenActionsIdentifiable) -> [TokenInstanceAction] {
        return [.init(type: .swap(service: self))]
    }

    public init(subProviders: [SupportedTokenActionsProvider & TokenActionProvider], action: String) {
        self.subProviders = subProviders
        self.action = action
    }

    public func start() {
        subProviders.forEach { $0.start() }
    }
}
