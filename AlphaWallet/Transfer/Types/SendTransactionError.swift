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
            return R.string.localizable.sendTransactionErrorPossibleBinanceTestnetTimeout(preferredLanguages: Languages.preferred())
        case .rateLimited:
            return R.string.localizable.sendTransactionErrorRateLimited(preferredLanguages: Languages.preferred())
        case .networkConnectionWasLost:
            return R.string.localizable.sendTransactionErrorNetworkConnectionWasLost(preferredLanguages: Languages.preferred())
        case .invalidCertificate:
            return R.string.localizable.sendTransactionErrorInvalidCertificate(preferredLanguages: Languages.preferred())
        case .requestTimedOut:
            return R.string.localizable.sendTransactionErrorRequestTimedOut(preferredLanguages: Languages.preferred())
        }
    }
}
