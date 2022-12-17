//
//  Request.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.12.2022.
//

import Foundation
import JSONRPCKit

public protocol RpcRequest: URLRequestConvertible {
    associatedtype Response

    var server: RPCServer { get }
    var rpcUrl: URL { get }
    var decoder: AnyDecoder { get }

    func intercept(urlRequest: URLRequest) throws -> URLRequest
    func intercept(object: Any, urlResponse: HTTPURLResponse) throws -> Any
    func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Response
}

extension RpcRequest {
    public func intercept(urlRequest: URLRequest) throws -> URLRequest {
        return urlRequest
    }

    public func intercept(object: Any, urlResponse: HTTPURLResponse) throws -> Any {
        guard 200..<300 ~= urlResponse.statusCode else {
            throw ResponseError.unacceptableStatusCode(urlResponse.statusCode)
        }
        return object
    }

    func parse(data: Data, urlResponse: HTTPURLResponse) throws -> Response {
        let parsedObject = try decoder.decode(response: urlResponse, data: data)
        let passedObject = try intercept(object: parsedObject, urlResponse: urlResponse)
        return try response(from: passedObject, urlResponse: urlResponse)
    }
}

public enum BlockParameter: RawRepresentable {
    public init?(rawValue: String) {
        return nil
    }

    public typealias RawValue = String

    case blockNumber(value: Int)
    case earliest
    case latest
    case pending

    public var rawValue: RawValue {
        switch self {
        case .blockNumber(let value):
            return "0x" + String(value, radix: 16)
        case .earliest:
            return "earliest"
        case .latest:
            return "latest"
        case .pending:
            return "pending"
        }
    }

}
