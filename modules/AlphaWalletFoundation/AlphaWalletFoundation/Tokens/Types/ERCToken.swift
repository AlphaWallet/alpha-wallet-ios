// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public struct ERCToken {
    public let contract: AlphaWallet.Address
    public let server: RPCServer
    public let name: String
    public let symbol: String
    public let decimals: Int
    public let type: TokenType
    public let balance: NonFungibleBalance

    public init(contract: AlphaWallet.Address, server: RPCServer, name: String, symbol: String, decimals: Int, type: TokenType, balance: NonFungibleBalance) {
        self.contract = contract
        self.server = server
        self.name = name
        self.symbol = symbol
        self.decimals = decimals
        self.type = type
        self.balance = balance
    }
}
