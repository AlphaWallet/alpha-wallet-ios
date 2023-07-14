// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import AlphaWalletCore
import BigInt
import JSONRPCKit

public struct BlockNumberRequest: JSONRPCKit.Request {
    public typealias Response = Int

    public var method: String {
        return "eth_blockNumber"
    }

    public init() {
    }

    public func response(from resultObject: Any) throws -> Response {
        if let response = resultObject as? String, let value = BigInt(response.drop0x, radix: 16) {
            return numericCast(value)
        } else {
            throw CastError(actualValue: resultObject, expectedType: Response.self)
        }
    }
}
