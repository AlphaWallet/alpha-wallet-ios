//
//  SwapPair.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Foundation

public struct SwapPair: Equatable {
    public var from: Token
    public var to: Token?

    public init(from: Token, to: Token? = nil) {
        self.from = from
        self.to = to
    }
    public static func == (_ lhs: SwapPair, _ rhs: SwapPair) -> Bool {
        return lhs.from == rhs.from && lhs.to == rhs.to
    }

    public var asFromAndToTokens: FromAndToTokens? {
        to.flatMap { FromAndToTokens(from: TokenToSwap(token: from), to: TokenToSwap(token: $0)) }
    }
}
