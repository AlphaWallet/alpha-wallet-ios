// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import JSONRPCKit

public enum SessionTaskError: Error {
    /// Error of `URLSession`.
    case connectionError(Error)

    /// Error while creating `URLRequest` from `Request`.
    case requestError(Error)

    /// Error while creating `Request.Response` from `(Data, URLResponse)`.
    case responseError(Error)
}

public typealias JSONRPCError = JSONRPCKit.JSONRPCError

public enum ResponseError: Error {
    /// Indicates the session adapter returned `URLResponse` that fails to down-cast to `HTTPURLResponse`.
    case nonHTTPURLResponse(URLResponse?)

    /// Indicates `HTTPURLResponse.statusCode` is not acceptable.
    /// In most cases, *acceptable* means the value is in `200..<300`.
    case unacceptableStatusCode(Int)

    /// Indicates `Any` that represents the response is unexpected.
    case unexpectedObject(Any)
}

private class SharedNumberIdGenerator: IdGenerator {

    fileprivate static var currentId = 1

    init() {}

    func next() -> Id {
        defer {
            SharedNumberIdGenerator.currentId += 1
        }

        return .number(SharedNumberIdGenerator.currentId)
    }
}

public struct JsonRpcRequest<R: JSONRPCKit.Request>: RpcRequest {
    public typealias Response = Batch1<R>.Responses

    private var headerFields: [String: String] = [:]

    public let request: Batch1<R>
    public let server: RPCServer
    public let rpcUrl: URL

    public init(server: RPCServer, rpcURL: URL, request: Batch1<R>) {
        self.server = server
        self.rpcUrl = rpcURL
        self.request = request
    }

    public init(server: RPCServer, request: R) {
        self.server = server
        self.rpcUrl = server.rpcURL
        self.request = BatchFactory(version: "2.0", idGenerator: SharedNumberIdGenerator()).create(request)
    }

    init(server: RPCServer, rpcURL: URL, rpcHeaders: [String: String], request: R) {
        self.server = server
        self.request = BatchFactory(version: "2.0", idGenerator: SharedNumberIdGenerator()).create(request)
        self.headerFields = rpcHeaders
        self.rpcUrl = rpcURL
    }

    public var decoder: AnyDecoder {
        AnyJsonDecoder(options: [])
    }

    public func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Response {
        return try request.responses(from: object)
    }

    public func asURLRequest() throws -> URLRequest {
        let headers = rpcUrl
            .generateBasicAuthCredentialsHeaders()
            .merging(with: headerFields.merging(with: ["accept": "application/json"]))

        var urlRequest = try URLRequest(url: rpcUrl, method: .post, headers: headers)
        urlRequest = try JSONEncoding().encode(urlRequest, withJSONObject: request.requestObject)

        return try intercept(urlRequest: urlRequest)
    }
}

extension URL {
    func generateBasicAuthCredentialsHeaders() -> [String: String] {
        guard let username = user, let password = password  else { return [:] }
        guard let authorization = "\(username):\(password)".data(using: .utf8)?.base64EncodedString() else { return [:] }

        return ["Authorization": "Basic \(authorization)"]
    }
}

extension Dictionary {
    static func += (lhs: inout Self, rhs: Self) {
        lhs.merge(rhs) { _ , new in new }
    }

    func merging(with other: [Key: Value]) -> Self {
        var _self = self
        for (k, v) in other {
            _self.updateValue(v, forKey: k)
        }

        return _self
    }
}
