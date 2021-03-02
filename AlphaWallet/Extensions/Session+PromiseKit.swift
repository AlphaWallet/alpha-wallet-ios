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
}

struct RateLimitError: LocalizedError {
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
            RemoteLogger.instance.logRpcOrOtherWebError("Connection Error | \(e.localizedDescription)", url: baseUrl.absoluteString)
            return nil
        case .requestError(let e):
            RemoteLogger.instance.logRpcOrOtherWebError("Request Error | \(e.localizedDescription)", url: baseUrl.absoluteString)
            return nil
        case .responseError(let e):
            if let jsonRpcError = e as? JSONRPCError {
                switch jsonRpcError {
                case .responseError(let code, let message, _):
                    if message.lowercased().hasPrefix("insufficient funds") {
                        RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.responseError | code: \(code) | message: \(message) | as: InsufficientFundsError()", url: baseUrl.absoluteString)
                        return InsufficientFundsError()
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

            RemoteLogger.instance.logRpcOrOtherWebError("Response Error: \(e.localizedDescription)", url: baseUrl.absoluteString)
            return nil
        }
    }
}

extension RPCServer {
    static func serverWithRpcURL(_ string: String) -> RPCServer? {
        RPCServer.allCases.first { $0.rpcURL.absoluteString == string }
    }
}