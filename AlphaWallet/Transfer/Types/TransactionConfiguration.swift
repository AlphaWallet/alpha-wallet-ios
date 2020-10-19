// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

struct TransactionConfiguration {
    var gasPrice: BigInt
    var gasLimit: BigInt
    let data: Data
    let nonce: Int?
    var hasUserAdjustedGasPrice: Bool
    var hasUserAdjustedGasLimit: Bool

    init(gasPrice: BigInt, gasLimit: BigInt, data: Data, nonce: Int? = nil, hasUserAdjustedGasPrice: Bool = false, hasUserAdjustedGasLimit: Bool = false) {
        self.gasPrice = gasPrice
        self.gasLimit = gasLimit
        self.data = data
        self.nonce = nonce
        self.hasUserAdjustedGasPrice = hasUserAdjustedGasPrice
        self.hasUserAdjustedGasLimit = hasUserAdjustedGasLimit
    }

    mutating func setEstimated(gasPrice estimate: BigInt) {
        guard !hasUserAdjustedGasPrice else { return }
        hasUserAdjustedGasPrice = true
        gasPrice = estimate
    }

    mutating func setEstimated(gasLimit estimate: BigInt) {
        guard !hasUserAdjustedGasLimit else { return }
        hasUserAdjustedGasLimit = true
        gasLimit = estimate
    }
}
