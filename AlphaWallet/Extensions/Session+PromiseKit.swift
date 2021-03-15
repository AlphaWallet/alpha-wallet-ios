// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import APIKit
import JSONRPCKit
import PromiseKit

struct InsufficientFundsError: LocalizedError {
    var errorDescription: String? {
        R.string.localizable.configureTransactionNotEnoughFunds()
    }
}
struct PossibleBinanceTestnetTimeoutError: LocalizedError {
    var errorDescription: String? {
        //TODO remove after mapping to better UI and message. Hence not localized yet
        "Request has timed out. Please try again"
    }
}
struct RateLimitError: LocalizedError {
    var errorDescription: String? {
        //TODO remove after mapping to better UI and message. Hence not localized yet
        "There might have been too many requests. Please try again later"
    }
}
struct ExecutionRevertedError: LocalizedError {
    private let message: String

    init(message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
struct NonceTooLowError: LocalizedError {
    var errorDescription: String? {
        //TODO remove after mapping to better UI and message. Hence not localized yet
        "The nonce of the transaction is too low"
    }
}
struct GasPriceTooLow: LocalizedError {
    var errorDescription: String? {
        //TODO remove after mapping to better UI and message. Hence not localized yet
        "The gas price specified for this transaction is too low"
    }
}
struct GasLimitTooLow: LocalizedError {
    var errorDescription: String? {
        //TODO remove after mapping to better UI and message. Hence not localized yet
        "The gas limit specified for this transaction is too low"
    }
}
struct GasLimitTooHigh: LocalizedError {
    var errorDescription: String? {
        //TODO remove after mapping to better UI and message. Hence not localized yet
        "The gas limit specified for this transaction is too high"
    }
}
struct PossibleChainIdMismatchError: LocalizedError {
    var errorDescription: String? {
        //TODO remove after mapping to better UI and message. Hence not localized yet
        "invalid sender: The chain ID might be wrong"
    }
}
struct NetworkConnectionWasLostError: LocalizedError {
    var errorDescription: String? {
        //TODO remove after mapping to better UI and message. Hence not localized yet
        "The network connection was lost. Please try again"
    }
}
struct InvalidCertificationError: LocalizedError {
    var errorDescription: String? {
        //TODO remove after mapping to better UI and message. Hence not localized yet
        "It seems like there is a problem with the RPC node certificate. Please try again later"
    }
}
struct RequestTimedOutError: LocalizedError {
    var errorDescription: String? {
        //TODO remove after mapping to better UI and message. Hence not localized yet
        "Request has timed out. Please try again"
    }
}

extension Session {
    class func send<Request: APIKit.Request>(_ request: Request, callbackQueue: CallbackQueue? = nil) -> Promise<Request.Response> {
        Promise { seal in
            Session.send(request, callbackQueue: callbackQueue) { result in
                switch result {
                case .success(let result):
                    seal.fulfill(result)
                case .failure(let error):
                    if let e = convertToUSerFriendlyError(error: error, baseUrl: request.baseURL) {
                        seal.reject(e)
                    } else {
                        seal.reject(error)
                    }
                }
            }
        }
    }

    private static func convertToUSerFriendlyError(error: SessionTaskError, baseUrl: URL) -> Error? {
        switch error {
        case .connectionError(let e):
            let message = e.localizedDescription
            if message.hasPrefix("The network connection was lost") {
                RemoteLogger.instance.logRpcOrOtherWebError("Connection Error | \(e.localizedDescription) | as: NetworkConnectionWasLostError()", url: baseUrl.absoluteString)
                return NetworkConnectionWasLostError()
            } else if message.hasPrefix("The certificate for this server is invalid") {
                RemoteLogger.instance.logRpcOrOtherWebError("Connection Error | \(e.localizedDescription) | as: InvalidCertificationError()", url: baseUrl.absoluteString)
                return InvalidCertificationError()
            } else if message.hasPrefix("The request timed out") {
                RemoteLogger.instance.logRpcOrOtherWebError("Connection Error | \(e.localizedDescription) | as: RequestTimedOutError()", url: baseUrl.absoluteString)
                return RequestTimedOutError()
            }
            RemoteLogger.instance.logRpcOrOtherWebError("Connection Error | \(e.localizedDescription)", url: baseUrl.absoluteString)
            return nil
        case .requestError(let e):
            RemoteLogger.instance.logRpcOrOtherWebError("Request Error | \(e.localizedDescription)", url: baseUrl.absoluteString)
            return nil
        case .responseError(let e):
            if let jsonRpcError = e as? JSONRPCError {
                switch jsonRpcError {
                case .responseError(let code, let message, _):
                    //Lowercased as RPC nodes implementation differ
                    if message.lowercased().hasPrefix("insufficient funds") {
                        RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.responseError | code: \(code) | message: \(message) | as: InsufficientFundsError()", url: baseUrl.absoluteString)
                        return InsufficientFundsError()
                    } else if message.lowercased().hasPrefix("execution reverted") || message.lowercased().hasPrefix("vm execution error") || message.lowercased().hasPrefix("revert") {
                        RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.responseError | code: \(code) | message: \(message) | as: ExecutionRevertedError()", url: baseUrl.absoluteString)
                        return ExecutionRevertedError(message: "message")
                    } else if message.lowercased().hasPrefix("nonce too low") || message.lowercased().hasPrefix("nonce is too low") {
                        RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.responseError | code: \(code) | message: \(message) | as: NonceTooLowError()", url: baseUrl.absoluteString)
                        return NonceTooLowError()
                    } else if message.lowercased().hasPrefix("transaction underpriced") {
                        RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.responseError | code: \(code) | message: \(message) | as: GasPriceTooLow()", url: baseUrl.absoluteString)
                        return GasPriceTooLow()
                    } else if message.lowercased().hasPrefix("intrinsic gas too low") || message.lowercased().hasPrefix("Transaction gas is too low") {
                        RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.responseError | code: \(code) | message: \(message) | as: GasLimitTooLow()", url: baseUrl.absoluteString)
                        return GasLimitTooLow()
                    } else if message.lowercased().hasPrefix("intrinsic gas exceeds gas limit") {
                        RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.responseError | code: \(code) | message: \(message) | as: GasLimitTooHigh()", url: baseUrl.absoluteString)
                        return GasLimitTooHigh()
                    } else if message.lowercased().hasPrefix("invalid sender") {
                        RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.responseError | code: \(code) | message: \(message) | as: PossibleChainIdMismatchError()", url: baseUrl.absoluteString)
                        return PossibleChainIdMismatchError()
                    } else {
                        RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.responseError | code: \(code) | message: \(message)", url: baseUrl.absoluteString)
                    }
                case .responseNotFound(_, let object):
                    RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.responseNotFound | object: \(object)", url: baseUrl.absoluteString)
                case .resultObjectParseError(let e):
                    RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.resultObjectParseError | error: \(e.localizedDescription)", url: baseUrl.absoluteString)
                case .errorObjectParseError(let e):
                    RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.errorObjectParseError | error: \(e.localizedDescription)", url: baseUrl.absoluteString)
                case .unsupportedVersion(let str):
                    RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.unsupportedVersion | str: \(str)", url: baseUrl.absoluteString)
                case .unexpectedTypeObject(let obj):
                    RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.unexpectedTypeObject | obj: \(obj)", url: baseUrl.absoluteString)
                case .missingBothResultAndError(let obj):
                    RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.missingBothResultAndError | obj: \(obj)", url: baseUrl.absoluteString)
                case .nonArrayResponse(let obj):
                    RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.nonArrayResponse | obj: \(obj)", url: baseUrl.absoluteString)
                }
                return nil
            }

            if let apiKitError = e as? APIKit.ResponseError {
                switch apiKitError {
                case .nonHTTPURLResponse:
                    RemoteLogger.instance.logRpcOrOtherWebError("APIKit.ResponseError.nonHTTPURLResponse", url: baseUrl.absoluteString)
                case .unacceptableStatusCode(let statusCode):
                    if statusCode == 429 {
                        RemoteLogger.instance.logRpcOrOtherWebError("APIKit.ResponseError.unacceptableStatusCode | status: \(statusCode) -> RateLimitError()", url: baseUrl.absoluteString)
                        return RateLimitError()
                    } else {
                        RemoteLogger.instance.logRpcOrOtherWebError("APIKit.ResponseError.unacceptableStatusCode | status: \(statusCode)", url: baseUrl.absoluteString)
                    }
                case .unexpectedObject(let obj):
                    RemoteLogger.instance.logRpcOrOtherWebError("APIKit.ResponseError.unexpectedObject | obj: \(obj)", url: baseUrl.absoluteString)
                }
                return nil
            }

            if RPCServer.binance_smart_chain_testnet.rpcURL.absoluteString == baseUrl.absoluteString, e.localizedDescription == "The data couldn’t be read because it isn’t in the correct format." {
                RemoteLogger.instance.logRpcOrOtherWebError("\(e.localizedDescription) -> PossibleBinanceTestnetTimeoutError()", url: baseUrl.absoluteString)
                //This is potentially Binance testnet timing out
                return PossibleBinanceTestnetTimeoutError()
            }

            RemoteLogger.instance.logRpcOrOtherWebError("Other Error: \(e) | \(e.localizedDescription)", url: baseUrl.absoluteString)
            return nil
        }
    }
}

extension RPCServer {
    static func serverWithRpcURL(_ string: String) -> RPCServer? {
        RPCServer.allCases.first { $0.rpcURL.absoluteString == string }
    }
}