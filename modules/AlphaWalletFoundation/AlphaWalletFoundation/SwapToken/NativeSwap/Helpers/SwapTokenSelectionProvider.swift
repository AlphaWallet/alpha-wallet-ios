//
//  SwapTokenSelectionProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import Foundation
import Combine

public final class SwapTokenSelectionProvider: TokenFilterProtocol {
    private let configurator: SwapOptionsConfigurator
    public private (set) var pendingTokenSelection: SwapTokens.TokenSelection? = .none

    public var objectWillChange: AnyPublisher<Void, Never> {
        configurator.tokenSwapper.objectWillChange
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    public init(configurator: SwapOptionsConfigurator) {
        self.configurator = configurator
    }

    public func set(pendingTokenSelection: SwapTokens.TokenSelection) {
        self.pendingTokenSelection = pendingTokenSelection
    }

    public func resetPendingTokenSelection() {
        pendingTokenSelection = .none
    }

    public func filter(token: TokenFilterable) -> Bool {
        guard
            let swapPairs = configurator.swapPairs(for: configurator.server),
            let selection = pendingTokenSelection
        else { return false }

        let fromToken = SwappableToken(address: configurator.swapPair.from.contractAddress, server: configurator.swapPair.from.server)
        let selectedToToken = configurator.swapPair.to.flatMap { SwappableToken(address: $0.contractAddress, server: $0.server) }
        let selectingToken = SwappableToken(address: token.contractAddress, server: token.server)

        switch selection {
        case .from:
            let containsInFromTokens = swapPairs.fromTokens.contains(selectingToken)

            if let token = selectedToToken {
                let nonSameAsAlreadySelectedTo = token != selectingToken
                return containsInFromTokens && nonSameAsAlreadySelectedTo
            } else {
                return containsInFromTokens
            }
        case .to:
            let toTokens = swapPairs.getToTokens(forFromToken: fromToken)
            let containsInToTokens = toTokens.contains(selectingToken)
            let nonSameAsFrom = fromToken != selectingToken

            return containsInToTokens && nonSameAsFrom
        }
    }
}
