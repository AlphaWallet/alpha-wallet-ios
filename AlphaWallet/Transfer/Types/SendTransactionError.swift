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

enum RpcNodeRetryableRequestError: LocalizedError {
    //TODO move those that aren't retryable to a not-retryable version
    case possibleBinanceTestnetTimeout
    //TODO rate limited means we should retry after delay. Or maybe all retries should have a delay
    case rateLimited(server: RPCServer, domainName: String)
    case networkConnectionWasLost
    case invalidCertificate
    case requestTimedOut
    case invalidApiKey(server: RPCServer, domainName: String)

    var errorDescription: String? {
        switch self {
        case .possibleBinanceTestnetTimeout:
            //TODO "send transaction" in name?
            return R.string.localizable.sendTransactionErrorPossibleBinanceTestnetTimeout()
        case .rateLimited:
            return R.string.localizable.sendTransactionErrorRateLimited()
        case .networkConnectionWasLost:
            return R.string.localizable.sendTransactionErrorNetworkConnectionWasLost()
        case .invalidCertificate:
            return R.string.localizable.sendTransactionErrorInvalidCertificate()
        case .requestTimedOut:
            return R.string.localizable.sendTransactionErrorRequestTimedOut()
        case .invalidApiKey:
            return R.string.localizable.sendTransactionErrorInvalidKey()
        }
    }
}