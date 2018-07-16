// Copyright SIX DAY LLC. All rights reserved.

import TrustKeystore

struct ERCToken {
    let contract: Address
    let name: String
    let symbol: String
    let decimals: Int
    let type: TokenType
    let balance: [String]
}
