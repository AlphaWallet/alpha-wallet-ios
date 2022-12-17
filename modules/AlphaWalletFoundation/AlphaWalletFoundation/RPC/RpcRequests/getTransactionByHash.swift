// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import AlphaWalletLogger

extension RpcRequest {
    static func getTransactionByHash(hash: String) -> RpcRequest {
        RpcRequest(method: "eth_getTransactionByHash", params: [hash])
    }
}

struct PendingTransactionDecoder {
    private let hash: String

    init(hash: String) {
        self.hash = hash
    }

    func decode(response: RpcResponse) throws -> EthereumTransaction? {
        switch response.outcome {
        case .response(let value):
            if value.value is NSNull {
                infoLog("[RPC] Fetch transaction by hash: \(hash) is null")
                return nil
            }

            guard let dict = value.value as? [String: AnyObject] else {
                throw CastError(actualValue: value.value, expectedType: EthereumTransaction?.self)
            }
            return EthereumTransaction(dictionary: dict)
        case .error(let error):
            throw error
        }
    }
}
