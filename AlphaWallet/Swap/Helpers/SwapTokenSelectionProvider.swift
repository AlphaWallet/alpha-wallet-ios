//
//  SwapTokenSelectionProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import Foundation

final class SwapTokenSelectionProvider: TokenFilterProtocol {
    private let configurator: SwapOptionsConfigurator
    private (set) var pendingTokenSelection: SwapTokens.TokenSelection? = .none

    init(configurator: SwapOptionsConfigurator) {
        self.configurator = configurator
    }

    func set(pendingTokenSelection: SwapTokens.TokenSelection) {
        self.pendingTokenSelection = pendingTokenSelection
    }

    func resetPendingTokenSelection() {
        pendingTokenSelection = .none
    }

    func filter(token: TokenFilterable) -> Bool {
        guard
            let swapPairs = configurator.swapPairs(forServer: configurator.server),
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
