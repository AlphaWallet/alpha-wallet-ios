//
//  TransactionReceiptRequest.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 28.10.2022.
//

import Foundation
import AlphaWalletWeb3
import BigInt

extension RpcRequest {
    static func getTransactionReceipt(hash: String) -> RpcRequest {
        RpcRequest(method: "eth_getTransactionReceipt", params: [hash])
    }
}

struct TransactionReceiptDecoder {
    func decode(response: RpcResponse) throws -> TransactionReceipt {
        switch response.outcome {
        case .response(let value):
            do {
                let data = try Data(json: value.value)
                return try JSONDecoder().decode(TransactionReceipt.self, from: data)
            } catch {
                throw CastError(actualValue: value, expectedType: TransactionReceipt.self)
            }
        case .error(let error):
            throw error
        }
    }
}
