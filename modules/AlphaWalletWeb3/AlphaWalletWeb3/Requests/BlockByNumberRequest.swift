//
//  BlockByNumberRequest.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 28.10.2022.
//

import Foundation
import AlphaWalletCore
import AlphaWalletWeb3
import BigInt
import JSONRPCKit

public struct BlockByNumberRequest: JSONRPCKit.Request {
    public typealias Response = Block

    let number: BigUInt
    var fullTransactions: Bool = false
    public var method: String {
        return "eth_getBlockByNumber"
    }

    public var parameters: Any? {
        return [String(number, radix: 16).add0x, fullTransactions]
    }

    public init(number: BigUInt) {
        self.number = number
    }

    public func response(from resultObject: Any) throws -> Response {
        do {
            let data = try Data(json: resultObject)
            return try JSONDecoder().decode(Block.self, from: data)
        } catch {
            throw CastError(actualValue: resultObject, expectedType: Response.self)
        }
    }
}
