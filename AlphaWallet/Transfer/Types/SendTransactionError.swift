// Copyright © 2022 Stormbird PTE. LTD.

import Foundation

enum SendTransactionNotRetryableError: Error {
    case insufficientFunds(message: String)
    case nonceTooLow(message: String)
    case gasPriceTooLow(message: String)
    case gasLimitTooLow(message: String)
    case gasLimitTooHigh(message: String)
    case possibleChainIdMismatch(message: String)
    case executionReverted(message: String)
}

enum SendTransactionRetryableError: LocalizedError {
    case possibleBinanceTestnetTimeout
    case rateLimited
    case networkConnectionWasLost
    case invalidCertificate
    case requestTimedOut

    var errorDescription: String? {
        switch self {
        case .possibleBinanceTestnetTimeout:
            return R.string.localizable.sendTransactionErrorPossibleBinanceTestnetTimeout()
        case .rateLimited:
            return R.string.localizable.sendTransactionErrorRateLimited()
        case .networkConnectionWasLost:
            return R.string.localizable.sendTransactionErrorNetworkConnectionWasLost()
        case .invalidCertificate:
            return R.string.localizable.sendTransactionErrorInvalidCertificate()
        case .requestTimedOut:
            return R.string.localizable.sendTransactionErrorRequestTimedOut()
        }
    }
}