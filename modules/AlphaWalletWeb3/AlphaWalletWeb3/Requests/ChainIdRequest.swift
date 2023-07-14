// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import AlphaWalletCore
import JSONRPCKit

public struct ChainIdRequest: JSONRPCKit.Request {
    public typealias Response = Int
    public var method: String {
        return "eth_chainId"
    }

    public init() {
    }

    public func response(from resultObject: Any) throws -> Response {
        if let response = resultObject as? String, let chainId = Int(chainId0xString: response) {
            return chainId
        } else {
            throw CastError(actualValue: resultObject, expectedType: Response.self)
        }
    }
}
