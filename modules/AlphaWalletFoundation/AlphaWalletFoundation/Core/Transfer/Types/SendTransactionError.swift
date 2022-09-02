// Copyright © 2022 Stormbird PTE. LTD.

import Foundation

public enum SendTransactionNotRetryableError: Error {
    case insufficientFunds(message: String)
    case nonceTooLow(message: String)
    case gasPriceTooLow(message: String)
    case gasLimitTooLow(message: String)
    case gasLimitTooHigh(message: String)
    case possibleChainIdMismatch(message: String)
    case executionReverted(message: String)
}

public enum RpcNodeRetryableRequestError: LocalizedError {
    //TODO move those that aren't retryable to a not-retryable version
    case possibleBinanceTestnetTimeout
    //TODO rate limited means we should retry after delay. Or maybe all retries should have a delay
    case rateLimited(server: RPCServer, domainName: String)
    case networkConnectionWasLost
    case invalidCertificate
    case requestTimedOut
    case invalidApiKey(server: RPCServer, domainName: String)
}
