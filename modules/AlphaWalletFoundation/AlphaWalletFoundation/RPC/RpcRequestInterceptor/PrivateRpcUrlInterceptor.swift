//
//  PrivateRpcUrlInterceptor.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 09.01.2023.
//

import Foundation

class PrivateRpcUrlInterceptor: RpcRequestInterceptor {
    private let privateNetworkParams: PrivateNetworkParams?

    //NOTE: might be we can apply private rpc fo any methods, it would be easier, previously it was only when we send trandaction
    var methods = ["eth_getTransactionCount", "eth_sendRawTransaction"]

    init(privateNetworkParams: PrivateNetworkParams?) {
        self.privateNetworkParams = privateNetworkParams
    }

    func intercept(request: (request: RpcRequest, rpcUrl: URL, headers: [String: String])) -> (request: RpcRequest, rpcUrl: URL, headers: [String: String]) {
        guard let params = privateNetworkParams, methods.contains(request.request.method) else { return request }

        return (request: request.request, rpcUrl: params.rpcUrl, headers: params.headers)
    }

    func intercept(request: (request: RpcRequestBatch, rpcUrl: URL, headers: [String: String])) -> (request: RpcRequestBatch, rpcUrl: URL, headers: [String: String]) {
//        guard let params = privateNetworkParams, methods.contains(request.request.method) else { return request }

//        return (request: request.request, rpcUrl: params.rpcUrl, headers: params.headers)
        return request
    }
}
