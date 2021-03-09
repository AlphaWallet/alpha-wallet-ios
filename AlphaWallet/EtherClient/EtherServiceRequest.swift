// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import APIKit
import JSONRPCKit

struct EtherServiceRequest<Batch: JSONRPCKit.Batch>: APIKit.Request {
    private let rpcURL: URL
    private let batch: Batch

    init(server: RPCServer, batch: Batch) {
        self.batch = batch
        self.rpcURL = server.rpcURL
    }

    init(rpcURL: URL, batch: Batch) {
        self.batch = batch
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

    func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Response {
        return try batch.responses(from: object)
    }
}
