//
//  SwapPair.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Foundation

struct SwapPair: Equatable {
    var from: Token
    var to: Token?

    static func == (_ lhs: SwapPair, _ rhs: SwapPair) -> Bool {
        return lhs.from == rhs.from && lhs.to == rhs.to
    }

    var asFromAndToTokens: FromAndToTokens? {
        to.flatMap { FromAndToTokens(from: TokenToSwap(token: from), to: TokenToSwap(token: $0)) }
    }
}
