// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation

extension RpcRequest {
    static func blockNumber() -> RpcRequest {
        RpcRequest(method: "eth_blockNumber")
    }

    static func call(to: AlphaWallet.Address, data: Data, block: BlockParameter = .latest) -> RpcRequest {
        let params = RpcParams(params: [["to": to.eip55String, "data": data.hexString.add0x], block] as [Any])

        return RpcRequest(method: "eth_call", params: params)
    }
}

struct BlockNumberDecoder {
    func decode(response: RpcResponse) throws -> Int {
        switch response.outcome {
        case .response(let value):
            let response = try value.get(String.self)
            if let value = BigInt(response.drop0x, radix: 16) {
                return numericCast(value)
            } else {
                throw CastError(actualValue: value, expectedType: Int.self)
            }
        case .error(let error):
            throw error
        }
    }
}
