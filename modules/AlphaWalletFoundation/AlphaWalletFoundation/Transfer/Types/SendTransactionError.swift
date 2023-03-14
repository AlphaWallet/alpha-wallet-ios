// Copyright © 2022 Stormbird PTE. LTD.

import Foundation

public struct SendTransactionNotRetryableError: Error {
    public enum ErrorType {
        case insufficientFunds(message: String)
        case nonceTooLow(message: String)
        case gasPriceTooLow(message: String)
        case gasLimitTooLow(message: String)
        case gasLimitTooHigh(message: String)
        case possibleChainIdMismatch(message: String)
        case executionReverted(message: String)
        case unknown(code: Int, message: String)
    }

    public let type: ErrorType
    public let server: RPCServer

    public init(type: ErrorType, server: RPCServer) {
        self.type = type
        self.server = server
    }
}

public enum RpcNodeRetryableRequestError: Error {
    //TODO move those that aren't retryable to a not-retryable version
    case possibleBinanceTestnetTimeout
    //TODO rate limited means we should retry after delay. Or maybe all retries should have a delay
    case rateLimited(server: RPCServer, domainName: String)
    case networkConnectionWasLost
    case invalidCertificate
    case requestTimedOut
    case invalidApiKey(server: RPCServer, domainName: String)
}
