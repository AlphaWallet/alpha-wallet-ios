// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

extension RpcRequest {
    static func estimateGas(from: AlphaWallet.Address, transactionType: EstimateGasTransactionType, value: BigUInt, data: Data, block: BlockParameter = .latest) -> RpcRequest {
        //Explicit type declaration to speed up build time. 160msec -> <100ms, as of Xcode 11.7
        var results: [[String: String]] = [
            [
                "from": from.description,
                "value": "0x" + String(value, radix: 16),
                "data": data.hexEncoded,
            ],
        ]
        if let to: AlphaWallet.Address = transactionType.contract {
            results[0]["to"] = to.eip55String
        }

        return RpcRequest(method: "eth_estimateGas", params: results)
    }
}

struct BigUIntDecoder {
    func decode(response: RpcResponse) throws -> BigUInt {
        switch response.outcome {
        case .response(let value):
            if let response = value.value as? String, let value = BigUInt(response.drop0x, radix: 16) {
                return value
            } else {
                throw CastError(actualValue: value.value, expectedType: BigUInt.self)
            }
        case .error(let error):
            throw error
        }
    }
}

