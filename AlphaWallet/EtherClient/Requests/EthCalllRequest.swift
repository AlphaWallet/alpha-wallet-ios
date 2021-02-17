// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import JSONRPCKit

struct EthCallRequest: JSONRPCKit.Request {
    typealias Response = String

    let from: AlphaWallet.Address?
    let to: AlphaWallet.Address?
    let data: String

    var method: String {
        return "eth_call"
    }

    var parameters: Any? {
        //Explicit type declaration to speed up build time. 160msec -> <100ms, as of Xcode 11.7
        var payload: [String: Any] = [
            "data": data
        ]
        if let to = to {
            payload["to"] = to.eip55String
        }
        if let from = from {
            payload["from"] = from.eip55String
        }
        let results: [Any] = [
            payload,
            "latest",
        ]
        return results
    }

    func response(from resultObject: Any) throws -> Response {
        if let response = resultObject as? Response {
            return response
        } else {
            throw CastError(actualValue: resultObject, expectedType: Response.self)
        }
    }
}