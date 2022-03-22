//
//  SwapQuoteState.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Foundation

//TODO: Fix error equatability
enum SwapQuoteState: Equatable {
    case pendingInput
    case fetching
    case completed(error: Error?)

    static func == (lhs: SwapQuoteState, rhs: SwapQuoteState) -> Bool {
        switch (lhs, rhs) {
        case (.pendingInput, .pendingInput), (.fetching, .fetching):
            return true
        case (.completed(let e1), .completed(let e2)):
            guard let e1 = e1, let e2 = e2 else { return true }
            return true//e1 == e2
        default:
            return false
        }
    }
}
