// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import APIKit
import JSONRPCKit

public typealias APIKitSession = APIKit.Session
public typealias SessionTaskError = APIKit.SessionTaskError
public typealias JSONRPCError = JSONRPCKit.JSONRPCError

public struct JsonRpcRequest<R: JSONRPCKit.Request>: RpcRequest {
    public typealias Response = Batch1<R>.Responses

    private let request: Batch1<R>
    private let method: APIKit.HTTPMethod = .post
    private var headerFields: [String: String] = [:]

    public let server: RPCServer
    public let rpcUrl: URL

    public init(server: RPCServer, request: R) {
        self.server = server
        self.rpcUrl = server.rpcURL
        self.request = BatchFactory().create(request)
    }

    init(server: RPCServer, rpcURL: URL, rpcHeaders: [String: String], request: R) {
        self.server = server
        self.request = BatchFactory().create(request)
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
        guard var components = URLComponents(url: rpcUrl, resolvingAgainstBaseURL: true) else {
            throw RequestError.invalidBaseURL(rpcUrl)
        }

        var urlRequest = URLRequest(url: rpcUrl)

        if let queryParameters = request.requestObject as? [String: Any], method.prefersQueryParameters && !queryParameters.isEmpty {
            components.percentEncodedQuery = URLEncodedSerialization.string(from: queryParameters)
        }

        if !method.prefersQueryParameters {
            let bodyParameters = JSONBodyParameters(JSONObject: request.requestObject)
            urlRequest.setValue(bodyParameters.contentType, forHTTPHeaderField: "Content-Type")

            switch try bodyParameters.buildEntity() {
            case .data(let data):
                urlRequest.httpBody = data

            case .inputStream(let inputStream):
                urlRequest.httpBodyStream = inputStream
            }
        }

        urlRequest.url = components.url
        urlRequest.httpMethod = method.rawValue
        urlRequest.setValue(decoder.contentType, forHTTPHeaderField: "Accept")

        headerFields.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        return (try intercept(urlRequest: urlRequest) as URLRequest)
    }
}
