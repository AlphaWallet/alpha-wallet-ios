//
//  TokenToSwap.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Foundation

public struct TokenToSwap {
    public let address: AlphaWallet.Address
    public let server: RPCServer
    public let symbol: String
    public let decimals: Int
}

extension TokenToSwap: Equatable, Codable {
    init(token: Token) {
        address = token.contractAddress
        server = token.server
        symbol = token.symbol
        decimals = token.decimals
    }

    init(tokenFromQuate token: SwapQuote.Token) {
        address = token.address
        server = RPCServer(chainID: token.chainId)
        symbol = token.symbol
        decimals = token.decimals
    }
}
