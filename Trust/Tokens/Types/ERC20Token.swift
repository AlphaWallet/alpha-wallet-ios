// Copyright SIX DAY LLC. All rights reserved.

import TrustKeystore

struct ERC20Token {
    let contract: Address
    let name: String
    let symbol: String
    let decimals: Int
    let isStormBird: Bool
    let balance: [Int16]
}
