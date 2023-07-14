//
//  TransactionReceiptRequest.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 28.10.2022.
//

import Foundation
import AlphaWalletCore
import AlphaWalletWeb3
import BigInt
import JSONRPCKit

public struct TransactionReceiptRequest: JSONRPCKit.Request {
    public typealias Response = TransactionReceipt

    let hash: String

    public var method: String {
        return "eth_getTransactionReceipt"
    }

    public var parameters: Any? {
        return [hash]
    }

    public init(hash: String) {
        self.hash = hash
    }

    public func response(from resultObject: Any) throws -> Response {
        do {
            let data = try Data(json: resultObject)
            return try JSONDecoder().decode(TransactionReceipt.self, from: data)
        } catch {
            throw CastError(actualValue: resultObject, expectedType: Response.self)
        }
    }
}
