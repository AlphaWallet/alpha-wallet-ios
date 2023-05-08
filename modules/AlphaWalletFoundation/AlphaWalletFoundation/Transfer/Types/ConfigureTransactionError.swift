// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation

public enum ConfigureTransactionError: Error {
    case gasPriceTooLow
    case gasLimitTooHigh
    case gasFeeTooHigh
    case nonceNotPositiveNumber
    case leaveNonceEmpty
}
