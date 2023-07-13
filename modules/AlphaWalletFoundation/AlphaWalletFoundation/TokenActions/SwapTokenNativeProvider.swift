//
//  SwapTokenNativeProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.05.2022.
//

import Foundation
import Combine

public final class SwapTokenNativeProvider: SupportedTokenActionsProvider, TokenActionProvider {
    private let tokenSwapper: TokenSwapper

    public var objectWillChange: AnyPublisher<Void, Never> {
        return tokenSwapper.objectWillChange
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
    public let analyticsName: String = "Native Swap"
    public let analyticsNavigation: Analytics.Navigation = .fallback
    public let action: String = "Native Swap"

    public init(tokenSwapper: TokenSwapper) {
        self.tokenSwapper = tokenSwapper
    }

    public func isSupport(token: TokenActionsIdentifiable) -> Bool {
        guard Features.current.isAvailable(.isSwapEnabled) else { return false }
        return tokenSwapper.supports(contractAddress: token.contractAddress, server: token.server)
    }

    public func actions(token: TokenActionsIdentifiable) -> [TokenInstanceAction] {
        return [.init(type: .swap(service: self))]
    }

    public func start() {
        tokenSwapper.start()
    }
}
