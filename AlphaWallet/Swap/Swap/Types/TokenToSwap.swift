//
//  TokenToSwap.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Foundation

struct TokenToSwap: Equatable, Codable {
    let address: AlphaWallet.Address
    let server: RPCServer
    let symbol: String
    let decimals: Int

    init(token: Token) {
        address = token.contractAddress
        server = token.server
        symbol = token.symbol
        decimals = token.decimals
    }
}
