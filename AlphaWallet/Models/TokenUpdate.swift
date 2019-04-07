// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore

struct TokenUpdate {
    let address: Address
    let server: RPCServer
    let name: String
    let symbol: String
    let decimals: Int
    var primaryKey: String {
         return TokenObject.generatePrimaryKey(fromContract: address.eip55String, server: server)
    }
}
