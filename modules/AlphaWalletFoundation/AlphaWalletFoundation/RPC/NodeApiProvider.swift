//
//  NodeApiProvider.swift
//  Alamofire
//
//  Created by Vladyslav Shepitko on 19.12.2022.
//

import JSONRPCKit
import PromiseKit
import Combine

public protocol NodeApiProvider {
    func dataTaskPromise<R: JSONRPCKit.Request>(_ request: R) -> PromiseKit.Promise<R.Response>
    func dataTaskPublisher<R: JSONRPCKit.Request>(_ request: R) -> AnyPublisher<R.Response, SessionTaskError>
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

final class WebSocketNodeApiProvider: NodeApiProvider {

    init(url: URL) {

    }

    func dataTaskPromise<R>(_ request: R) -> PromiseKit.Promise<R.Response> where R: JSONRPCKit.Request {
        fatalError("Not Implemented")
    }

    func dataTaskPublisher<R>(_ request: R) -> AnyPublisher<R.Response, SessionTaskError> where R: JSONRPCKit.Request {
        fatalError("Not Implemented")
    }
}

public protocol NodeApiRequestInterceptor {
    func intercept<R: JSONRPCKit.Request>(request: JsonRpcRequest<R>) -> JsonRpcRequest<R>
}
private class NoInterceptionInterceptor: NodeApiRequestInterceptor {
    func intercept<R: JSONRPCKit.Request>(request: JsonRpcRequest<R>) -> JsonRpcRequest<R> {
        return request
    }
}

class PrivateRpcNodeInterceptor: NodeApiRequestInterceptor {
    //NOTE: might be we can apply private rpc fo any methods, it would be easier, previously it was only when we send trandaction
    var privateNetworkRpcMethods = ["eth_getTransactionCount", "eth_sendRawTransaction"]
    private let privateNetworkParams: PrivateNetworkParams?
    private let server: RPCServer

    init(server: RPCServer, privateNetworkParams: PrivateNetworkParams?) {
        self.server = server
        self.privateNetworkParams = privateNetworkParams
    }

    func intercept<R: JSONRPCKit.Request>(request: JsonRpcRequest<R>) -> JsonRpcRequest<R> {
        guard let params = privateNetworkParams, privateNetworkRpcMethods.contains(request.embeded.method) else {
            return request
        }

        return JsonRpcRequest(
            server: server,
            rpcURL: params.rpcUrl,
            rpcHeaders: params.headers,
            request: request.embeded)
    }
}

public final class NodeRpcApiProvider: NodeApiProvider {
    private let rpcApiProvider: RpcApiProvider
    private let server: RPCServer
    private let rpcHttpParams: RpcHttpParams
    public var shouldUseNextRpc: (_ error: SessionTaskError) -> Bool = { _ in
        //TODO: update with select next rpc url logic
        return false
    }
    public var requestInterceptor: NodeApiRequestInterceptor = NoInterceptionInterceptor()

    public init(rpcApiProvider: RpcApiProvider, server: RPCServer, rpcHttpParams: RpcHttpParams) {
        self.server = server
        self.rpcApiProvider = rpcApiProvider
        self.rpcHttpParams = rpcHttpParams
    }

    public func dataTaskPromise<R: JSONRPCKit.Request>(_ request: R) -> PromiseKit.Promise<R.Response> {
        return dataTaskPromise(request, rpcUrlIndex: 0)
    }

    private func dataTaskPromise<R: JSONRPCKit.Request>(_ request: R, rpcUrlIndex: Int) -> PromiseKit.Promise<R.Response> {
        let rpcRequest = buildRpcRequest(with: rpcUrlIndex, for: request)

        return firstly {
            .value(rpcRequest)
        }.map { [requestInterceptor] in requestInterceptor.intercept(request: $0) }
        .then { [rpcApiProvider, shouldUseNextRpc] rpcRequest in
            rpcApiProvider
                .dataTaskPromise(rpcRequest)
                .recover { error -> PromiseKit.Promise<R.Response> in
                    guard let error = error as? SessionTaskError else { return .init(error: error) }

                    if shouldUseNextRpc(error) {
                        return self.dataTaskPromise(request, rpcUrlIndex: rpcUrlIndex + 1)
                    } else {
                        return .init(error: error)
                    }
                }
        }
    }

    public func dataTaskPublisher<R: JSONRPCKit.Request>(_ request: R) -> AnyPublisher<R.Response, SessionTaskError> {
        return dataTaskPublisher(request, rpcUrlIndex: 0)
    }

    private func dataTaskPublisher<R: JSONRPCKit.Request>(_ request: R, rpcUrlIndex: Int) -> AnyPublisher<R.Response, SessionTaskError> {
        let rpcRequest = buildRpcRequest(with: rpcUrlIndex, for: request)

        return Just(rpcRequest)
            .setFailureType(to: SessionTaskError.self)
            .map { [requestInterceptor] in requestInterceptor.intercept(request: $0) }
            .flatMap { [rpcApiProvider, shouldUseNextRpc] rpcRequest in
                rpcApiProvider
                    .dataTaskPublisher(rpcRequest)
                    .catch { error -> AnyPublisher<R.Response, SessionTaskError> in
                        if shouldUseNextRpc(error) {
                            return self.dataTaskPublisher(request, rpcUrlIndex: rpcUrlIndex + 1)
                        } else {
                            return .fail(error)
                        }
                    }.eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }

    private func buildRpcRequest<R: JSONRPCKit.Request>(with rpcUrlIndex: Int, for request: R) -> JsonRpcRequest<R> {
        return JsonRpcRequest(
            server: server,
            rpcURL: rpcHttpParams.rpcUrls[rpcUrlIndex % rpcHttpParams.rpcUrls.count],
            rpcHeaders: rpcHttpParams.headers,
            request: request)
    }
}
