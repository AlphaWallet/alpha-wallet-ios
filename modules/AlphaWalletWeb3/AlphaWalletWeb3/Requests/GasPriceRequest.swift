// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import AlphaWalletCore
import BigInt
import JSONRPCKit

public struct GasPriceRequest: JSONRPCKit.Request {
    public typealias Response = BigUInt

    public var method: String {
        return "eth_gasPrice"
    }

    public init() {
    }

    public func response(from resultObject: Any) throws -> Response {
        if let response = resultObject as? String, let value = BigUInt(response.drop0x, radix: 16) {
            return value
        } else {
            throw CastError(actualValue: resultObject, expectedType: Response.self)
        }
    }
}
