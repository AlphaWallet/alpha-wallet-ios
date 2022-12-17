//
//  RpcRequestInterceptor.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 09.01.2023.
//

import Foundation

public typealias RpcHttpRequest<T> = (request: T, rpcUrl: URL, headers: [String: String])

public protocol RpcRequestInterceptor {
    func intercept(request: RpcHttpRequest<RpcRequest>) -> RpcHttpRequest<RpcRequest>
    func intercept(request: RpcHttpRequest<RpcRequestBatch>) -> RpcHttpRequest<RpcRequestBatch>
}

class NoInterceptionInterceptor: RpcRequestInterceptor {
    func intercept(request: RpcHttpRequest<RpcRequest>) -> RpcHttpRequest<RpcRequest> {
        return request
    }

    func intercept(request: RpcHttpRequest<RpcRequestBatch>) -> RpcHttpRequest<RpcRequestBatch> {
        return request
    }
}
