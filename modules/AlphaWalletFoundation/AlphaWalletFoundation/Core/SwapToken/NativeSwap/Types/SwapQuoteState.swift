//
//  SwapQuoteState.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Foundation

//TODO: Fix error equatability
public enum SwapQuoteState: Equatable {
    case pendingInput
    case fetching
    case completed(error: Error?)

    public static func == (lhs: SwapQuoteState, rhs: SwapQuoteState) -> Bool {
        switch (lhs, rhs) {
        case (.pendingInput, .pendingInput), (.fetching, .fetching):
            return true
        case (.completed, .completed):
            return true
        default:
            return false
        }
    }
}
