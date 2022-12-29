//
//  BlockByNumberRequest.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 28.10.2022.
//

import Foundation
import AlphaWalletWeb3
import BigInt
import JSONRPCKit

struct BlockByNumberRequest: JSONRPCKit.Request {
    typealias Response = Block

    let number: BigUInt
    var fullTransactions: Bool = false
    var method: String {
        return "eth_getBlockByNumber"
    }

    var parameters: Any? {
        return [String(number, radix: 16).add0x, fullTransactions]
    }

    func response(from resultObject: Any) throws -> Response {
        do {
            let data = try Data(json: resultObject)
            return try JSONDecoder().decode(Block.self, from: data)
        } catch {
            throw CastError(actualValue: resultObject, expectedType: Response.self)
        }
    }
}
