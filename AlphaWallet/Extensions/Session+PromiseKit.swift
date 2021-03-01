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
                    if case let .responseError(JSONRPCError.responseError(_, message: message, _)) = error {
                        RemoteLogger.instance.logRpcOrOtherWebError(message, url: request.baseURL.absoluteString)
                        if message.lowercased().hasPrefix("insufficient funds") {
                            seal.reject(InsufficientFundsError())
                        } else {
                            seal.reject(error)
                        }
                        return
                    }

                    if case let SessionTaskError.responseError(APIKit.ResponseError.unacceptableStatusCode(statusCode)) = error {
                        RemoteLogger.instance.logRpcOrOtherWebError("\(error.localizedDescription) | status: \(statusCode)", url: request.baseURL.absoluteString)
                        if statusCode == 429 {
                            seal.reject(RateLimitError())
                        } else {
                            seal.reject(error)
                        }
                        return
                    }

                    if case let SessionTaskError.responseError(e) = error, RPCServer.binance_smart_chain_testnet.rpcURL.absoluteString == request.baseURL.absoluteString, e.localizedDescription == "The data couldn’t be read because it isn’t in the correct format." {
                        //This is potentially Binance testnet timing out
                        seal.reject(PossibleBinanceTestnetTimeoutError())
                        return
                    }

                    if case let SessionTaskError.connectionError(e) = error {
                        RemoteLogger.instance.logRpcOrOtherWebError("Connection Error: \(e.localizedDescription)", url: request.baseURL.absoluteString)
                        seal.reject(error)
                        return
                    }
                    if case let SessionTaskError.requestError(e) = error {
                        RemoteLogger.instance.logRpcOrOtherWebError("Request Error: \(e.localizedDescription)", url: request.baseURL.absoluteString)
                        seal.reject(error)
                        return
                    }
                    if case let SessionTaskError.responseError(e) = error {
                        RemoteLogger.instance.logRpcOrOtherWebError("Response Error: \(e.localizedDescription)", url: request.baseURL.absoluteString)
                        seal.reject(error)
                        return
                    }

                    RemoteLogger.instance.logRpcOrOtherWebError(error.localizedDescription, url: request.baseURL.absoluteString)
                    seal.reject(error)
                }
            }
        }
    }
}

extension RPCServer {
    static func serverWithRpcURL(_ string: String) -> RPCServer? {
        RPCServer.allCases.first { $0.rpcURL.absoluteString == string }
    }
}