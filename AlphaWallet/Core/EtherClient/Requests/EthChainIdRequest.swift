// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import JSONRPCKit

struct EthChainIdRequest: JSONRPCKit.Request {
    typealias Response = String
    var method: String {
        return "eth_chainId"
    }

    func response(from resultObject: Any) throws -> Response {
        if let response = resultObject as? Response {
            return response
        } else {
            throw CastError(actualValue: resultObject, expectedType: Response.self)
        }
    }
}