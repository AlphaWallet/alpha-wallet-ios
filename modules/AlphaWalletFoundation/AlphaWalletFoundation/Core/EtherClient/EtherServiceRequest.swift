// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import APIKit
import JSONRPCKit

public struct EtherServiceRequest<Batch: JSONRPCKit.Batch>: APIKit.Request {
    private let rpcURL: URL
    private let rpcHeaders: [String: String]
    private let batch: Batch

    public init(server: RPCServer, batch: Batch) {
        self.batch = batch
        self.rpcURL = server.rpcURL
        self.rpcHeaders = server.rpcHeaders
    }

    init(rpcURL: URL, rpcHeaders: [String: String], batch: Batch) {
        self.batch = batch
        self.rpcHeaders = rpcHeaders
        self.rpcURL = rpcURL
    }

    public typealias Response = Batch.Responses

    public var baseURL: URL {
        return rpcURL
    }

    public var method: HTTPMethod {
        return .post
    }

    public var path: String {
        return ""
    }

    public var parameters: Any? {
        return batch.requestObject
    }

    public var headerFields: [String: String] {
        return rpcHeaders
    }

    public func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Response {
        return try batch.responses(from: object)
    }
}
