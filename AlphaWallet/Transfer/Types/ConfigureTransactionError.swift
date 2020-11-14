// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

enum ConfigureTransactionError: Error {
    case gasLimitTooLow
    case gasLimitTooHigh
    case gasFeeTooHigh
    case nonceNotPositiveNumber

    var localizedDescription: String {
        switch self {
        case .gasLimitTooHigh:
            return R.string.localizable.configureTransactionErrorGasLimitTooHigh(ConfigureTransaction.gasLimitMax)
        case .gasFeeTooHigh:
            return R.string.localizable.configureTransactionErrorGasFeeTooHigh(EtherNumberFormatter.short.string(from: BigInt(ConfigureTransaction.gasFeeMax)))
        case .nonceNotPositiveNumber:
            return R.string.localizable.configureTransactionErrorNonceNotPositiveNumber()
        case .gasLimitTooLow:
            return R.string.localizable.configureTransactionErrorGasPriceTooLow()
        }
    }
}
