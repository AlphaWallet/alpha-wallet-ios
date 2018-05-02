// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

enum ConfigureTransactionError: LocalizedError {
    case gasLimitTooHigh
    case gasFeeTooHigh

    var errorDescription: String? {
        switch self {
        case .gasLimitTooHigh:
            return R.string.localizable.configureTransactionErrorGasLimitTooHigh(ConfigureTransaction.gasLimitMax)
        case .gasFeeTooHigh:
            return R.string.localizable.configureTransactionErrorGasFeeTooHigh(String(ConfigureTransaction.gasFeeMax))
        }
    }
}
