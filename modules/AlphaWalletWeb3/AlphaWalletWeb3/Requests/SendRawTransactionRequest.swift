// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import AlphaWalletCore
import JSONRPCKit

public struct SendRawTransactionRequest: JSONRPCKit.Request {
    public typealias Response = String

    let signedTransaction: String

    public var method: String {
        return "eth_sendRawTransaction"
    }

    public var parameters: Any? {
        return [
            signedTransaction,
        ]
    }

    public init(signedTransaction: String) {
        self.signedTransaction = signedTransaction
    }

    public func response(from resultObject: Any) throws -> Response {
        if let response = resultObject as? Response {
            return response
        } else {
            throw CastError(actualValue: resultObject, expectedType: Response.self)
        }
    }
}