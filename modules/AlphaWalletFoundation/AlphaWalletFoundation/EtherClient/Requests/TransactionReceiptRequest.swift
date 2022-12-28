//
//  TransactionReceiptRequest.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 28.10.2022.
//

import Foundation
import AlphaWalletWeb3
import BigInt
import JSONRPCKit

struct TransactionReceiptRequest: JSONRPCKit.Request {
    typealias Response = TransactionReceipt

    let hash: String

    var method: String {
        return "eth_getTransactionReceipt"
    }

    var parameters: Any? {
        return [hash]
    }

    func response(from resultObject: Any) throws -> Response {
        do {
            let data = try Data(json: resultObject)
            return try JSONDecoder().decode(TransactionReceipt.self, from: data)
        } catch {
            throw CastError(actualValue: resultObject, expectedType: Response.self)
        }
    }
}
