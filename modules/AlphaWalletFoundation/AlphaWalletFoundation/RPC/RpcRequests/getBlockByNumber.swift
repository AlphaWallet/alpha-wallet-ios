//
//  BlockByNumberRequest.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 28.10.2022.
//

import Foundation
import AlphaWalletWeb3
import BigInt

extension RpcRequest {
    static func getBlockByNumber(number: BigUInt, fullTransactions: Bool = false) -> RpcRequest {
        let params = RpcParams(params: [String(number, radix: 16).add0x, fullTransactions] as [Any])
        return RpcRequest(method: "eth_getBlockByNumber", params: params)
    }
}

struct BlockByNumberDecoder {
    func decode(response: RpcResponse) throws -> Block {
        switch response.outcome {
        case .response(let value):
            do {
                let data = try Data(json: value.value)
                return try JSONDecoder().decode(Block.self, from: data)
            } catch {
                throw CastError(actualValue: value.value, expectedType: Block.self)
            }
        case .error(let error):
            throw error
        }
    }
}

