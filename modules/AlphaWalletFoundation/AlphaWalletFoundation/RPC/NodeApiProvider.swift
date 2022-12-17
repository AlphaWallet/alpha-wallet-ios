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

final class WebSocketNodeApiProvider: NodeApiProvider {
    func dataTaskPromise<R>(_ request: R) -> PromiseKit.Promise<R.Response> where R: JSONRPCKit.Request {
        fatalError("Not Implemented")
    }

    func dataTaskPublisher<R>(_ request: R) -> AnyPublisher<R.Response, SessionTaskError> where R: JSONRPCKit.Request {
        fatalError("Not Implemented")
    }
}

public final class NodeRpcApiProvider: NodeApiProvider {
    private let rpcApiProvider: RpcApiProvider
    private let config: Config
    private let server: RPCServer

    public init(rpcApiProvider: RpcApiProvider, config: Config, server: RPCServer) {
        self.server = server
        self.rpcApiProvider = rpcApiProvider
        self.config = config
    }

    public func dataTaskPromise<R: JSONRPCKit.Request>(_ request: R) -> PromiseKit.Promise<R.Response> {
        let (rpcURL, rpcHeaders) = rpcURLAndHeaders
        let request = JsonRpcRequest(
            server: server,
            rpcURL: rpcURL,
            rpcHeaders: rpcHeaders,
            request: request)

        return rpcApiProvider
            .dataTaskPromise(request)
    }

    public func dataTaskPublisher<R: JSONRPCKit.Request>(_ request: R) -> AnyPublisher<R.Response, SessionTaskError> {
        let (rpcURL, rpcHeaders) = rpcURLAndHeaders
        let request = JsonRpcRequest(
            server: server,
            rpcURL: rpcURL,
            rpcHeaders: rpcHeaders,
            request: request)

        return rpcApiProvider
            .dataTaskPublisher(request)
    }

    private var rpcURLAndHeaders: (url: URL, rpcHeaders: [String: String]) {
        server.rpcUrlAndHeadersWithReplacementSendPrivateTransactionsProviderIfEnabled(config: config)
    }
}
