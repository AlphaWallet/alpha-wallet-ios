// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import AlphaWalletLogger
import APIKit
import JSONRPCKit
import PromiseKit

extension APIKitSession {

    private class func sendImpl<Request: APIKit.Request>(_ request: Request, server: RPCServer, analytics: AnalyticsLogger, callbackQueue: CallbackQueue? = nil) -> Promise<Request.Response> {
        let (promise, seal) = Promise<Request.Response>.pending()
        APIKitSession.send(request, callbackQueue: callbackQueue) { result in
            switch result {
            case .success(let result):
                seal.fulfill(result)
            case .failure(let error):
                if let e = convertToUserFriendlyError(error: error, server: server, baseUrl: request.baseURL) {
                    if let e = e as? RpcNodeRetryableRequestError {
                        logRpcNodeError(e, analytics: analytics)
                    }

                    seal.reject(e)
                } else {
                    seal.reject(error)
                }
            }
        }

        return promise
    }

    static func logRpcNodeError(_ rpcNodeError: RpcNodeRetryableRequestError, analytics: AnalyticsLogger) {
        switch rpcNodeError {
        case .rateLimited(let server, let domainName):
            analytics.log(error: Analytics.WebApiErrors.rpcNodeRateLimited, properties: [Analytics.Properties.chain.rawValue: server.chainID, Analytics.Properties.domainName.rawValue: domainName])
        case .invalidApiKey(let server, let domainName):
            analytics.log(error: Analytics.WebApiErrors.rpcNodeInvalidApiKey, properties: [Analytics.Properties.chain.rawValue: server.chainID, Analytics.Properties.domainName.rawValue: domainName])
        case .possibleBinanceTestnetTimeout, .networkConnectionWasLost, .invalidCertificate, .requestTimedOut:
            return
        }
    }

    public class func send<Request: APIKit.Request>(_ request: Request, server: RPCServer, analytics: AnalyticsLogger, callbackQueue: CallbackQueue? = nil) -> Promise<Request.Response> {
        let promise = sendImpl(request, server: server, analytics: analytics, callbackQueue: callbackQueue)
        return firstly {
            promise
        }.recover { error -> Promise<Request.Response> in
            if error is RpcNodeRetryableRequestError {
                return sendImpl(request, server: server, analytics: analytics, callbackQueue: callbackQueue)
            } else {
                return promise
            }
        }
    }

    //TODO we should make sure we only call this RPC nodes because the errors we map to mentions "RPC"
    // swiftlint:disable function_body_length
    public static func convertToUserFriendlyError(error: SessionTaskError, server: RPCServer, baseUrl: URL) -> Error? {
        infoLog("convertToUserFriendlyError URL: \(baseUrl.absoluteString) error: \(error)")
        switch error {
        case .connectionError(let e):
            let message = e.localizedDescription
            if message.hasPrefix("The network connection was lost") {
                RemoteLogger.instance.logRpcOrOtherWebError("Connection Error | \(e.localizedDescription) | as: NetworkConnectionWasLostError()", url: baseUrl.absoluteString)
                return RpcNodeRetryableRequestError.networkConnectionWasLost
            } else if message.hasPrefix("The certificate for this server is invalid") {
                RemoteLogger.instance.logRpcOrOtherWebError("Connection Error | \(e.localizedDescription) | as: InvalidCertificateError()", url: baseUrl.absoluteString)
                return RpcNodeRetryableRequestError.invalidCertificate
            } else if message.hasPrefix("The request timed out") {
                RemoteLogger.instance.logRpcOrOtherWebError("Connection Error | \(e.localizedDescription) | as: RequestTimedOutError()", url: baseUrl.absoluteString)
                return RpcNodeRetryableRequestError.requestTimedOut
            }
            RemoteLogger.instance.logRpcOrOtherWebError("Connection Error | \(e.localizedDescription)", url: baseUrl.absoluteString)
            return nil
        case .requestError(let e):
            RemoteLogger.instance.logRpcOrOtherWebError("Request Error | \(e.localizedDescription)", url: baseUrl.absoluteString)
            return nil
        case .responseError(let e):
            if let nsError = e as? NSError, nsError.code == 3840 {
                //handle when json decode error
                return SendTransactionNotRetryableError(type: .unknown(code: nsError.code, message: "Something went wrong"), server: server)
            }

            if let jsonRpcError = e as? JSONRPCError {
                switch jsonRpcError {
                case .responseError(let code, let message, _):
                    //Lowercased as RPC nodes implementation differ
                    if message.lowercased().hasPrefix("insufficient funds") {
                        return SendTransactionNotRetryableError(type: .insufficientFunds(message: message), server: server)
                    } else if message.lowercased().hasPrefix("execution reverted") || message.lowercased().hasPrefix("vm execution error") || message.lowercased().hasPrefix("revert") {
                        return SendTransactionNotRetryableError(type: .executionReverted(message: message), server: server)
                    } else if message.lowercased().hasPrefix("nonce too low") || message.lowercased().hasPrefix("nonce is too low") {
                        return SendTransactionNotRetryableError(type: .nonceTooLow(message: message), server: server)
                    } else if message.lowercased().hasPrefix("transaction underpriced") || message.lowercased().hasPrefix("feetoolow") {
                        return SendTransactionNotRetryableError(type: .gasPriceTooLow(message: message), server: server)
                    } else if message.lowercased().hasPrefix("intrinsic gas too low") || message.lowercased().hasPrefix("Transaction gas is too low") {
                        return SendTransactionNotRetryableError(type: .gasLimitTooLow(message: message), server: server)
                    } else if message.lowercased().hasPrefix("intrinsic gas exceeds gas limit") {
                        return SendTransactionNotRetryableError(type: .gasLimitTooHigh(message: message), server: server)
                    } else if message.lowercased().hasPrefix("invalid sender") {
                        return SendTransactionNotRetryableError(type: .possibleChainIdMismatch(message: message), server: server)
                    } else if message == "Upfront cost exceeds account balance" {
                        //Spotted for Palm chain (mainnet)
                        return SendTransactionNotRetryableError(type: .insufficientFunds(message: message), server: server)
                    } else {
                        RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.responseError | code: \(code) | message: \(message)", url: baseUrl.absoluteString)
                        return SendTransactionNotRetryableError(type: .unknown(code: code, message: message), server: server)
                    }
                case .responseNotFound(_, let object):
                    RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.responseNotFound | object: \(object)", url: baseUrl.absoluteString)
                case .resultObjectParseError(let e):
                    RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.resultObjectParseError | error: \(e.localizedDescription)", url: baseUrl.absoluteString)
                case .errorObjectParseError(let e):
                    RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.errorObjectParseError | error: \(e.localizedDescription)", url: baseUrl.absoluteString)
                case .unsupportedVersion(let str):
                    //If there's an error and the payload is missing the "jsonrpc" key (and the HTTP status code is still `200`), JSONRPCKit interprets that as `.unsupportedVersion`. But the error could be (eg. https://klaytn-baobab.blockpi.network/v1/rpc/ for Klaytn) `{"error":{"code":-32000,"message":"The apikey format is wrong"}}`                                                                    `
                    if let host = baseUrl.host, ["klaytn.blockpi.network", "klaytn-baobab.blockpi.network"].contains(host) {
                        return RpcNodeRetryableRequestError.invalidApiKey(server: server, domainName: baseUrl.host ?? "")
                    } else {
                        RemoteLogger.instance.logRpcOrOtherWebError("JSONRPCError.unsupportedVersion | str: \(String(describing: str))", url: baseUrl.absoluteString)
                    }
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
                    if statusCode == 401 {
                        warnLog("[API] Invalid API key with baseURL: \(baseUrl.absoluteString)")
                        return RpcNodeRetryableRequestError.invalidApiKey(server: server, domainName: baseUrl.host ?? "")
                    } else if statusCode == 429 {
                        warnLog("[API] Rate limited by baseURL: \(baseUrl.absoluteString)")
                        return RpcNodeRetryableRequestError.rateLimited(server: server, domainName: baseUrl.host ?? "")
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
                return RpcNodeRetryableRequestError.possibleBinanceTestnetTimeout
            }

            RemoteLogger.instance.logRpcOrOtherWebError("Other Error: \(e) | \(e.localizedDescription)", url: baseUrl.absoluteString)
            return nil
        }
    }
    // swiftlint:enable function_body_length
}

extension RPCServer {
    public static func serverWithRpcURL(_ string: String) -> RPCServer? {
        RPCServer.availableServers.first { $0.rpcURL.absoluteString == string }
    }
}
