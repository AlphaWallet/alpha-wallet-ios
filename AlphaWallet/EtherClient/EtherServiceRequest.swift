// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import APIKit
import JSONRPCKit

struct EtherServiceRequest<Batch: JSONRPCKit.Batch>: APIKit.Request {
    private let rpcURL: URL
    private let rpcHeaders: [String: String]
    private let batch: Batch

    init(server: RPCServer, batch: Batch) {
        self.batch = batch
        self.rpcURL = server.rpcURL
        self.rpcHeaders = server.rpcHeaders
    }

    init(rpcURL: URL, rpcHeaders: [String: String], batch: Batch) {
        self.batch = batch
        self.rpcHeaders = rpcHeaders
        self.rpcURL = rpcURL
    }

    typealias Response = Batch.Responses

    var baseURL: URL {
        return rpcURL
    }

    var method: HTTPMethod {
        return .post
    }

    var path: String {
        return ""
    }

    var parameters: Any? {
        return batch.requestObject
    }

    var headerFields: [String: String] {
        return rpcHeaders
    }

    func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Response {
        return try batch.responses(from: object)
    }
}
