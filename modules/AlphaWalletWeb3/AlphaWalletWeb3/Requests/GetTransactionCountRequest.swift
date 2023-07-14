// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import AlphaWalletAddress
import AlphaWalletCore
import BigInt
import JSONRPCKit

public struct GetTransactionCountRequest: JSONRPCKit.Request {
    public typealias Response = Int

    let address: AlphaWallet.Address
    let state: String

    public var method: String {
        return "eth_getTransactionCount"
    }

    public var parameters: Any? {
        return [
            address.eip55String,
            state,
        ]
    }

    public init(address: AlphaWallet.Address, state: String) {
        self.address = address
        self.state = state
    }

    public func response(from resultObject: Any) throws -> Response {
        if let response = resultObject as? String {
            return BigInt(response.drop0x, radix: 16).map({ numericCast($0) }) ?? 0
        } else {
            throw CastError(actualValue: resultObject, expectedType: Response.self)
        }
    }
}
