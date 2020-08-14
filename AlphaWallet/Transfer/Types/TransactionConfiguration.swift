// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

struct TransactionConfiguration {
    let gasPrice: BigInt
    var gasLimit: BigInt
    let data: Data
    let nonce: Int?

    init(gasPrice: BigInt, gasLimit: BigInt, data: Data, nonce: Int? = nil) {
        self.gasPrice = gasPrice
        self.gasLimit = gasLimit
        self.data = data
        self.nonce = nonce
    }
}
