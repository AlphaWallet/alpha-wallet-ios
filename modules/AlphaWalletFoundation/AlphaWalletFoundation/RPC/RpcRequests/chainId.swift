// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

extension RpcRequest {
    static func chainId() -> RpcRequest {
        RpcRequest(method: "eth_chainId")
    }
}

struct ChainIdDecoder {
    func decode(response: RpcResponse) throws -> Int {
        switch response.outcome {
        case .response(let value):
            if let response = value.value as? String, let chainId = Int(chainId0xString: response) {
                return chainId
            } else {
                throw CastError(actualValue: value.value, expectedType: Int.self)
            }
        case .error(let error):
            throw error
        }
    }
}
