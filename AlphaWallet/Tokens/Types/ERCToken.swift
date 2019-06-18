// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct ERCToken {
    let contract: AlphaWallet.Address
    let server: RPCServer
    let name: String
    let symbol: String
    let decimals: Int
    let type: TokenType
    let balance: [String]
}
