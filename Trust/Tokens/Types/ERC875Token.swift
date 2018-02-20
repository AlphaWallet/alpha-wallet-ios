// Copyright SIX DAY LLC. All rights reserved.

import TrustKeystore

struct ERC875Token {
    let contract: Address
    let name: String
    let symbol: String
    let balance: [ERC875Balance]
}
