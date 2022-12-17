// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation

extension RpcRequest {
    static func getBalance(address: AlphaWallet.Address, block: BlockParameter = .latest) -> RpcRequest {
        RpcRequest(method: "eth_getBalance", params: [address.eip55String, block.rawValue])
    }
}

struct BalanceDecoder {
    func decode(response: RpcResponse) throws -> Balance {
        switch response.outcome {
        case .response(let value):
            do {
                let response = try value.get(String.self)
                if let value = BigUInt(response.drop0x, radix: 16) {
                    return Balance(value: value)
                } else {
                    throw CastError(actualValue: value, expectedType: Balance.self)
                }
            } catch {
                throw error
            }
        case .error(let error):
            throw error
        }
    }
}

extension JSONRPCError: LocalizedError {
    public var errorDescription: String? {
        return message
    }
}

extension RpcResponse {
    func decode<T: Decodable & Encodable>(type: T.Type) throws -> T {
        switch outcome {
        case .error(let error):
            throw error
        case .response(let value):
            return try value.get(T.self)
        }
    }
}
