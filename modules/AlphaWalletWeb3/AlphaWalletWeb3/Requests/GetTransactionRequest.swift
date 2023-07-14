// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import AlphaWalletCore
import AlphaWalletLogger
import JSONRPCKit

public struct GetTransactionRequest: JSONRPCKit.Request {
    public typealias Response = EthereumTransaction?

    let hash: String

    public var method: String {
        return "eth_getTransactionByHash"
    }

    public var parameters: Any? {
        return [hash]
    }

    public init(hash: String) {
        self.hash = hash
    }

    public func response(from resultObject: Any) throws -> Response {
        if resultObject is NSNull {
            infoLog("[RPC] Fetch transaction by hash: \(hash) is null")
            return nil
        }
        guard let dict = resultObject as? [String: AnyObject] else {
            throw CastError(actualValue: resultObject, expectedType: Response.self)
        }

        return EthereumTransaction(dictionary: dict)
    }
}
