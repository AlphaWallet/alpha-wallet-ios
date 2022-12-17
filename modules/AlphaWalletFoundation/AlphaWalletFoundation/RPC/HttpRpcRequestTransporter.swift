//
//  RpcRequestTransporter.swift
//  Alamofire
//
//  Created by Vladyslav Shepitko on 19.12.2022.
//

import PromiseKit
import Combine
import BigInt
import AlphaWalletWeb3
import AlphaWalletCore
import AlphaWalletLogger
import Alamofire

public protocol RpcRequestTransporter {
    func dataTaskPublisher(_ request: RpcRequest) -> AnyPublisher<RpcResponse, SessionTaskError>
    func dataTaskPublisher(_ request: RpcRequestBatch) -> AnyPublisher<RpcResponseBatch, SessionTaskError>
}

public struct RpcHttpParams: Codable {
    public let rpcUrls: [URL]
    public let headers: [String: String]

    public init(rpcUrls: [URL], headers: [String: String]) {
        self.rpcUrls = rpcUrls
        self.headers = headers
    }
}

public struct PrivateNetworkParams: Codable {
    let rpcUrl: URL
    let headers: [String: String]

    public init(rpcUrl: URL, headers: [String: String]) {
        self.rpcUrl = rpcUrl
        self.headers = headers
    }
}

public enum RpcSource: Codable {
    case http(params: RpcHttpParams, privateParams: PrivateNetworkParams?)
    case webSocket(url: URL, privateParams: PrivateNetworkParams?)

    func adding(privateParams: PrivateNetworkParams?) -> RpcSource {
        switch self {
        case .http(let params, _):
            return .http(params: params, privateParams: privateParams)
        case .webSocket(let url, _):
            return .webSocket(url: url, privateParams: privateParams)
        }
    }
}

fileprivate extension JSONRPCError {
    var invalidResponseError: InvalidHttpResponseError? {
        return data.flatMap { try? $0.get(InvalidHttpResponseError.self) }
    }
}

public final class HttpRpcRequestTransporter: RpcRequestTransporter {
    private let server: RPCServer
    private let rpcHttpParams: RpcHttpParams
    private let analytics: AnalyticsLogger
    private let logger: RemoteLogger
    private let networkService: RpcNetworkService

    static var changeRpcUrlStatusCodes: [Int] = [404, 503]

    /// keeps latest rpc url index
    private (set) var rpcUrlIndex: Int = 0
    public var shouldUseNextRpc: (_ error: SessionTaskError) -> Bool = { error in
        switch error {
        case .responseError(let error):
            guard let error = error as? JSONRPCError, let response = error.invalidResponseError else { return false }

            return HttpRpcRequestTransporter.changeRpcUrlStatusCodes.contains(response.statusCode)
        case .requestError, .connectionError:
            return false
        }
    }

    public var requestInterceptor: RpcRequestInterceptor = NoInterceptionInterceptor()

    public init(server: RPCServer,
                rpcHttpParams: RpcHttpParams,
                networkService: RpcNetworkService,
                analytics: AnalyticsLogger,
                logger: RemoteLogger = .instance) {

        self.logger = logger
        self.analytics = analytics
        self.rpcHttpParams = rpcHttpParams
        self.server = server

        self.networkService = networkService
    }

    public func dataTaskPublisher(_ request: RpcRequest) -> AnyPublisher<RpcResponse, SessionTaskError> {
        dataTaskPublisher(request, rpcUrlIndex: rpcUrlIndex)
    }

    public func dataTaskPublisher(_ request: RpcRequestBatch) -> AnyPublisher<RpcResponseBatch, SessionTaskError> {
        dataTaskPublisher(request, rpcUrlIndex: rpcUrlIndex)
    }

    private func dataTaskPublisher(_ request: RpcRequestBatch, rpcUrlIndex: Int) -> AnyPublisher<RpcResponseBatch, SessionTaskError> {
        let rpcUrlData = buildNextRpcUrl(with: rpcUrlIndex)
        let data = requestInterceptor.intercept(request: (request: request, rpcUrl: rpcUrlData.rpcUrl, headers: rpcUrlData.headers))
        let urlRequest = JsonRpcRequest(payload: data.request, rpcUrl: data.rpcUrl, rpcHeaders: data.headers)

        return networkService.dataTaskPublisher(urlRequest)
            .map { resp -> RpcResponseBatch in
                do {
                    return try JSONDecoder().decode(RpcResponseBatch.self, from: resp.data)
                } catch {
                    let responses = request.requests.map { RpcResponse(id: $0.id, error: JSONRPCError.invalidResponse(response: resp)) }
                    return RpcResponseBatch(responses: responses)
                }
            }.catch { [weak self] error -> AnyPublisher<RpcResponseBatch, SessionTaskError> in
                guard let strongSelf = self else { return .empty() }

                if strongSelf.shouldUseNextRpc(error) {
                    return strongSelf.dataTaskPublisher(request, rpcUrlIndex: rpcUrlIndex + 1)
                } else {
                    return .fail(error)
                }
            }.mapError { self.mapToSesstionTaskError(error: $0, server: self.server, rpcUrl: data.rpcUrl) }
            .eraseToAnyPublisher()
    }

    private func dataTaskPublisher(_ request: RpcRequest, rpcUrlIndex: Int) -> AnyPublisher<RpcResponse, SessionTaskError> {
        let rpcUrlData = buildNextRpcUrl(with: rpcUrlIndex)
        let data = requestInterceptor.intercept(request: (request: request, rpcUrl: rpcUrlData.rpcUrl, headers: rpcUrlData.headers))
        let urlRequest = JsonRpcRequest(payload: data.request, rpcUrl: data.rpcUrl, rpcHeaders: data.headers)

        return networkService.dataTaskPublisher(urlRequest)
            .map { resp -> RpcResponse in
                do {
                    return try JSONDecoder().decode(RpcResponse.self, from: resp.data)
                } catch {
                    return RpcResponse(id: request.id, error: JSONRPCError.invalidResponse(response: resp))
                }
            }.catch { [weak self] error -> AnyPublisher<RpcResponse, SessionTaskError> in
                guard let strongSelf = self else { return .empty() }

                if strongSelf.shouldUseNextRpc(error) {
                    return strongSelf.dataTaskPublisher(request, rpcUrlIndex: rpcUrlIndex + 1)
                } else {
                    return .fail(error)
                }
            }.mapError { self.mapToSesstionTaskError(error: $0, server: self.server, rpcUrl: data.rpcUrl) }
            .eraseToAnyPublisher()
    }

    private func buildNextRpcUrl(with rpcUrlIndex: Int) -> (rpcUrl: URL, headers: [String: String]) {
        self.rpcUrlIndex = rpcUrlIndex
        return (rpcHttpParams.rpcUrls[rpcUrlIndex % rpcHttpParams.rpcUrls.count], rpcHttpParams.headers)
    }

    private func mapToSesstionTaskError(error: SessionTaskError, server: RPCServer, rpcUrl: URL) -> SessionTaskError {
        if let e = convertToUserFriendlyError(error: error, server: server, baseUrl: rpcUrl) {
            if let e = e as? RpcNodeRetryableRequestError {
               logRpcNodeError(e)
            }
            return SessionTaskError.responseError(e)
        } else {
            return error
        }
    }

    private func logRpcNodeError(_ rpcNodeError: RpcNodeRetryableRequestError) {
        switch rpcNodeError {
        case .rateLimited(let server, let domainName):
            analytics.log(error: Analytics.WebApiErrors.rpcNodeRateLimited, properties: [
                Analytics.Properties.chain.rawValue: server.chainID,
                Analytics.Properties.domainName.rawValue: domainName
            ])
        case .invalidApiKey(let server, let domainName):
            analytics.log(error: Analytics.WebApiErrors.rpcNodeInvalidApiKey, properties: [
                Analytics.Properties.chain.rawValue: server.chainID,
                Analytics.Properties.domainName.rawValue: domainName
            ])
        case .possibleBinanceTestnetTimeout, .networkConnectionWasLost, .invalidCertificate, .requestTimedOut:
            return
        }
    }

    //TODO we should make sure we only call this RPC nodes because the errors we map to mentions "RPC"
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
                if let e = jsonRpcError.invalidResponseError {
                    if e.statusCode == 401 {
                        warnLog("[API] Invalid API key with baseURL: \(baseUrl.absoluteString)")
                        return RpcNodeRetryableRequestError.invalidApiKey(server: server, domainName: baseUrl.host ?? "")
                    } else if e.statusCode == 429 {
                        warnLog("[API] Rate limited by baseURL: \(baseUrl.absoluteString)")
                        return RpcNodeRetryableRequestError.rateLimited(server: server, domainName: baseUrl.host ?? "")
                    } else {
                        logger.logRpcOrOtherWebError("APIKit.ResponseError.unacceptableStatusCode | status: \(e.statusCode)", url: baseUrl.absoluteString)
                    }
                } else {
                    let message = jsonRpcError.message
                    //NOTE: Lowercased as RPC nodes implementation differ
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
                        logger.logRpcOrOtherWebError("JSONRPCError.responseError | code: \(jsonRpcError.code) | message: \(message)", url: baseUrl.absoluteString)
                        return SendTransactionNotRetryableError(type: .unknown(code: jsonRpcError.code, message: message), server: server)
                    }
                }
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
}

extension RPCServer {

    public func rpcSource(config: Config) -> RpcSource {
        let privateParams = config.sendPrivateTransactionsProvider?.rpcUrl(forServer: self).flatMap { PrivateNetworkParams(rpcUrl: $0, headers: [:] ) }
        return .http(params: .init(rpcUrls: [rpcURL], headers: rpcHeaders), privateParams: privateParams)
    }

    public static func serverWithRpcURL(_ string: String) -> RPCServer? {
        RPCServer.availableServers.first { $0.rpcURL.absoluteString == string }
    }

}

struct JsonRpcRequest: URLRequestConvertible {
    let payload: Codable
    let rpcUrl: URL
    let rpcHeaders: [String: String]

    func asURLRequest() throws -> URLRequest {
        let headers = rpcUrl
            .generateBasicAuthCredentialsHeaders()
            .merging(with: rpcHeaders.merging(with: ["accept": "application/json"]))

        var urlRequest = try URLRequest(url: rpcUrl, method: .post, headers: HTTPHeaders(headers))
        urlRequest = try JSONEncoding().encode(urlRequest, codable: payload)

        return urlRequest
    }
}
