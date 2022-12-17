// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation

extension RpcRequest {
    static func getTransactionCount(address: AlphaWallet.Address, block: BlockParameter) -> RpcRequest {
        RpcRequest(method: "eth_getTransactionCount", params: [address.eip55String, block.rawValue])
    }
}

struct TransactionCountDecoder {
    func decode(response: RpcResponse) throws -> Int {
        switch response.outcome {
        case .response(let value):
            if let response = value.value as? String {
                return BigInt(response.drop0x, radix: 16).map({ numericCast($0) }) ?? 0
            } else {
                throw CastError(actualValue: value.value, expectedType: Int.self)
            }
        case .error(let error):
            throw error
        }
    }
}

