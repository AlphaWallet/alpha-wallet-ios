//
//  RpcApiProvider.swift
//  Alamofire
//
//  Created by Vladyslav Shepitko on 19.12.2022.
//

import Combine
import PromiseKit
import AlphaWalletCore
import APIKit

public protocol RpcApiProvider {
    func dataTaskPromise<R: RpcRequest>(_ request: R) -> Promise<R.Response>
    func dataTaskPublisher<R: RpcRequest>(_ request: R) -> AnyPublisher<R.Response, SessionTaskError>
}

public class BaseRpcApiProvider: RpcApiProvider {
    private let analytics: AnalyticsLogger
    private let networkService: NetworkService
    private let logger: RemoteLogger
    private let serialQueue = DispatchQueue(label: "org.alphawallet.swift.RpcApiProvider")
    //NOTE: might be conflicting when send same request via promise and publisher, would be fixed when promise version will be removed, use sepatte dictionaries for now
    private var inFlightPublishers: [URLRequest: Any] = [:]
    private var inFlightPromises: [URLRequest: Any] = [:]

    public let callbackQueue = DispatchQueue.global()
    public var retries: Int = 2

    public init(analytics: AnalyticsLogger, networkService: NetworkService, logger: RemoteLogger = .instance) {
        self.analytics = analytics
        self.networkService = networkService
        self.logger = logger
    }

    public func dataTaskPromise<R>(_ request: R) -> PromiseKit.Promise<R.Response> where R: RpcRequest {
        return firstly {
            .value(request)
        }.then(on: serialQueue, { [weak self, networkService, retries, serialQueue, callbackQueue] request -> PromiseKit.Promise<R.Response> in
            do {
                let urlRequest = try request.intercept(urlRequest: request.asURLRequest())

                if let promise = self?.inFlightPromises[urlRequest] as? PromiseKit.Promise<R.Response> {
                    return promise
                } else {
                    let promise = attempt(shouldOnlyRetryIf: { error in
                        return error is RpcNodeRetryableRequestError
                    }, {
                        return networkService
                            .dataTaskPromise(urlRequest)
                            .map { try request.parse(data: $0.data, urlResponse: $0.response) }
                            .recover { error -> Promise<R.Response> in
                                guard let error = error as? SessionTaskError else { return .init(error: error) }
                                if let e = self?.convertToUserFriendlyError(error: error, server: request.server, baseUrl: request.rpcUrl) {
                                    if let e = e as? RpcNodeRetryableRequestError {
                                        self?.logRpcNodeError(e)
                                    }

                                    return .init(error: e)
                                } else {
                                    return .init(error: error)
                                }
                            }
                    }).ensure(on: serialQueue, { self?.inFlightPromises[urlRequest] = .none })

                    self?.inFlightPromises[urlRequest]

                    return promise
                }
            } catch {
                return .init(error: SessionTaskError.requestError(error))
            }
        })
    }
    /// Performs rpc request, caches publisher and return shared publisher
    public func dataTaskPublisher<R>(_ request: R) -> AnyPublisher<R.Response, SessionTaskError> where R: RpcRequest {
        return Just(request)
            .receive(on: serialQueue)
            .setFailureType(to: SessionTaskError.self)
            .flatMap { [weak self, networkService, retries, serialQueue, callbackQueue] request -> AnyPublisher<R.Response, SessionTaskError> in
                do {
                    let urlRequest = try request.intercept(urlRequest: request.asURLRequest())

                    if let publisher = self?.inFlightPublishers[urlRequest] as? AnyPublisher<R.Response, SessionTaskError> {
                        return publisher
                    } else {
                        let publisher = networkService.dataTaskPublisher(urlRequest)
                            .tryMap { try request.parse(data: $0.data, urlResponse: $0.response) }
                            .mapError { error -> SessionTaskError in
                                guard let error = error as? SessionTaskError else { return .responseError(error)  }
                                if let e = self?.convertToUserFriendlyError(error: error, server: request.server, baseUrl: request.rpcUrl) {
                                    return .requestError(e)
                                } else {
                                    return error
                                }
                            }.retry(times: retries, when: {
                                guard case SessionTaskError.requestError(let e) = $0 else { return false }
                                if let e = e as? RpcNodeRetryableRequestError {
                                    self?.logRpcNodeError(e)
                                }
                                return e is RpcNodeRetryableRequestError
                            }).receive(on: serialQueue)
                            .handleEvents(receiveCompletion: { _ in self?.inFlightPublishers[urlRequest] = .none })
                            .receive(on: callbackQueue)
                            .share()
                            .eraseToAnyPublisher()

                        self?.inFlightPublishers[urlRequest] = publisher

                        return publisher
                    }
                } catch {
                    return .fail(SessionTaskError.requestError(error))
                }
            }.eraseToAnyPublisher()
    }

    private func logRpcNodeError(_ rpcNodeError: RpcNodeRetryableRequestError) {
        switch rpcNodeError {
        case .rateLimited(let server, let domainName):
            analytics.log(error: Analytics.WebApiErrors.rpcNodeRateLimited, properties: [Analytics.Properties.chain.rawValue: server.chainID, Analytics.Properties.domainName.rawValue: domainName])
        case .invalidApiKey(let server, let domainName):
            analytics.log(error: Analytics.WebApiErrors.rpcNodeInvalidApiKey, properties: [Analytics.Properties.chain.rawValue: server.chainID, Analytics.Properties.domainName.rawValue: domainName])
        case .possibleBinanceTestnetTimeout, .networkConnectionWasLost, .invalidCertificate, .requestTimedOut:
            return
        }
    }

    //TODO we should make sure we only call this RPC nodes because the errors we map to mentions "RPC"
    // swiftlint:disable function_body_length
    private func convertToUserFriendlyError(error: SessionTaskError, server: RPCServer, baseUrl: URL) -> Error? {
        infoLog("convertToUserFriendlyError URL: \(baseUrl.absoluteString) error: \(error)")
        switch error {
        case .connectionError(let e):
            let message = e.localizedDescription
            if message.hasPrefix("The network connection was lost") {
                logger.logRpcOrOtherWebError("Connection Error | \(e.localizedDescription) | as: NetworkConnectionWasLostError()", url: baseUrl.absoluteString)
                return RpcNodeRetryableRequestError.networkConnectionWasLost
            } else if message.hasPrefix("The certificate for this server is invalid") {
                logger.logRpcOrOtherWebError("Connection Error | \(e.localizedDescription) | as: InvalidCertificateError()", url: baseUrl.absoluteString)
                return RpcNodeRetryableRequestError.invalidCertificate
            } else if message.hasPrefix("The request timed out") {
                logger.logRpcOrOtherWebError("Connection Error | \(e.localizedDescription) | as: RequestTimedOutError()", url: baseUrl.absoluteString)
                return RpcNodeRetryableRequestError.requestTimedOut
            }
            logger.logRpcOrOtherWebError("Connection Error | \(e.localizedDescription)", url: baseUrl.absoluteString)
            return nil
        case .requestError(let e):
            logger.logRpcOrOtherWebError("Request Error | \(e.localizedDescription)", url: baseUrl.absoluteString)
            return nil
        case .responseError(let e):
            if let jsonRpcError = e as? JSONRPCError {
                switch jsonRpcError {
                case .responseError(let code, let message, _):
                    //Lowercased as RPC nodes implementation differ
                    if message.lowercased().hasPrefix("insufficient funds") {
                        return SendTransactionNotRetryableError.insufficientFunds(message: message)
                    } else if message.lowercased().hasPrefix("execution reverted") || message.lowercased().hasPrefix("vm execution error") || message.lowercased().hasPrefix("revert") {
                        return SendTransactionNotRetryableError.executionReverted(message: message)
                    } else if message.lowercased().hasPrefix("nonce too low") || message.lowercased().hasPrefix("nonce is too low") {
                        return SendTransactionNotRetryableError.nonceTooLow(message: message)
                    } else if message.lowercased().hasPrefix("transaction underpriced") || message.lowercased().hasPrefix("feetoolow") {
                        return SendTransactionNotRetryableError.gasPriceTooLow(message: message)
                    } else if message.lowercased().hasPrefix("intrinsic gas too low") || message.lowercased().hasPrefix("Transaction gas is too low") {
                        return SendTransactionNotRetryableError.gasLimitTooLow(message: message)
                    } else if message.lowercased().hasPrefix("intrinsic gas exceeds gas limit") {
                        return SendTransactionNotRetryableError.gasLimitTooHigh(message: message)
                    } else if message.lowercased().hasPrefix("invalid sender") {
                        return SendTransactionNotRetryableError.possibleChainIdMismatch(message: message)
                    } else if message == "Upfront cost exceeds account balance" {
                        //Spotted for Palm chain (mainnet)
                        return SendTransactionNotRetryableError.insufficientFunds(message: message)
                    } else {
                        logger.logRpcOrOtherWebError("JSONRPCError.responseError | code: \(code) | message: \(message)", url: baseUrl.absoluteString)
                        return SendTransactionNotRetryableError.unknown(code: code, message: message)
                    }
                case .responseNotFound(_, let object):
                    logger.logRpcOrOtherWebError("JSONRPCError.responseNotFound | object: \(object)", url: baseUrl.absoluteString)
                case .resultObjectParseError(let e):
                    logger.logRpcOrOtherWebError("JSONRPCError.resultObjectParseError | error: \(e.localizedDescription)", url: baseUrl.absoluteString)
                case .errorObjectParseError(let e):
                    logger.logRpcOrOtherWebError("JSONRPCError.errorObjectParseError | error: \(e.localizedDescription)", url: baseUrl.absoluteString)
                case .unsupportedVersion(let str):
                    logger.logRpcOrOtherWebError("JSONRPCError.unsupportedVersion | str: \(String(describing: str))", url: baseUrl.absoluteString)
                case .unexpectedTypeObject(let obj):
                    logger.logRpcOrOtherWebError("JSONRPCError.unexpectedTypeObject | obj: \(obj)", url: baseUrl.absoluteString)
                case .missingBothResultAndError(let obj):
                    logger.logRpcOrOtherWebError("JSONRPCError.missingBothResultAndError | obj: \(obj)", url: baseUrl.absoluteString)
                case .nonArrayResponse(let obj):
                    logger.logRpcOrOtherWebError("JSONRPCError.nonArrayResponse | obj: \(obj)", url: baseUrl.absoluteString)
                }
                return nil
            }

            if let apiKitError = e as? APIKit.ResponseError {
                switch apiKitError {
                case .nonHTTPURLResponse:
                    logger.logRpcOrOtherWebError("APIKit.ResponseError.nonHTTPURLResponse", url: baseUrl.absoluteString)
                case .unacceptableStatusCode(let statusCode):
                    if statusCode == 401 {
                        warnLog("[API] Invalid API key with baseURL: \(baseUrl.absoluteString)")
                        return RpcNodeRetryableRequestError.invalidApiKey(server: server, domainName: baseUrl.host ?? "")
                    } else if statusCode == 429 {
                        warnLog("[API] Rate limited by baseURL: \(baseUrl.absoluteString)")
                        return RpcNodeRetryableRequestError.rateLimited(server: server, domainName: baseUrl.host ?? "")
                    } else {
                        logger.logRpcOrOtherWebError("APIKit.ResponseError.unacceptableStatusCode | status: \(statusCode)", url: baseUrl.absoluteString)
                    }
                case .unexpectedObject(let obj):
                    logger.logRpcOrOtherWebError("APIKit.ResponseError.unexpectedObject | obj: \(obj)", url: baseUrl.absoluteString)
                }
                return nil
            }

            if RPCServer.binance_smart_chain_testnet.rpcURL.absoluteString == baseUrl.absoluteString, e.localizedDescription == "The data couldn’t be read because it isn’t in the correct format." {
                logger.logRpcOrOtherWebError("\(e.localizedDescription) -> PossibleBinanceTestnetTimeoutError()", url: baseUrl.absoluteString)
                //This is potentially Binance testnet timing out
                return RpcNodeRetryableRequestError.possibleBinanceTestnetTimeout
            }

            logger.logRpcOrOtherWebError("Other Error: \(e) | \(e.localizedDescription)", url: baseUrl.absoluteString)
            return nil
        }
    }
    // swiftlint:enable function_body_length
}

public enum RpcSource {
    case http
    case webSocket
}

extension RPCServer {
    var rpcSource: RpcSource {
        return .http
    }

    public static func serverWithRpcURL(_ string: String) -> RPCServer? {
        RPCServer.availableServers.first { $0.rpcURL.absoluteString == string }
    }

}
