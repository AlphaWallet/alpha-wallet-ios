// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import AlphaWalletAddress
import AlphaWalletCore
import BigInt
import JSONRPCKit

public struct BalanceRequest: JSONRPCKit.Request {
    public typealias Response = Balance

    let address: AlphaWallet.Address

    public var method: String {
        return "eth_getBalance"
    }

    public var parameters: Any? {
        return [address.eip55String, "latest"]
    }

    public init(address: AlphaWallet.Address) {
        self.address = address
    }

    public func response(from resultObject: Any) throws -> Response {
        if let response = resultObject as? String, let value = BigUInt(response.drop0x, radix: 16) {
            return Balance(value: value)
        } else {
            throw CastError(actualValue: resultObject, expectedType: Response.self)
        }
    }
}
