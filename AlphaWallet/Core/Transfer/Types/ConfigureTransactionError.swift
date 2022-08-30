// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

enum ConfigureTransactionError: Error {
    case gasPriceTooLow
    case gasLimitTooHigh
    case gasFeeTooHigh
    case nonceNotPositiveNumber
    case leaveNonceEmpty
}
