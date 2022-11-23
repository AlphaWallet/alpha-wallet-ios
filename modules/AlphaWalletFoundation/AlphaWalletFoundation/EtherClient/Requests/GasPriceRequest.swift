// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import JSONRPCKit
import BigInt

struct GasPriceRequest: JSONRPCKit.Request {
    typealias Response = BigUInt

    var method: String {
        return "eth_gasPrice"
    }

    func response(from resultObject: Any) throws -> Response {
        if let response = resultObject as? String, let value = BigUInt(response.drop0x, radix: 16) {
            return value
        } else {
            throw CastError(actualValue: resultObject, expectedType: Response.self)
        }
    }
}
