//
//  GetFeeHistory.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 16.08.2022.
//

extension RpcRequest {
    static func feeHistory(blockCount: Int, lastBlock: String, rewardPercentile: [Int]) -> RpcRequest {
        let params = RpcParams(params: [blockCount, lastBlock, rewardPercentile] as [Any])

        return RpcRequest(method: "eth_feeHistory", params: params)
    }
}

struct FeeHistoryDecoder {
    func decode(response: RpcResponse) throws -> FeeHistory {
        switch response.outcome {
        case .response(let value):
            guard let data = try? JSONSerialization.data(withJSONObject: value.value, options: []) else {
                throw CastError(actualValue: value.value, expectedType: FeeHistory.self)
            }
            if let data = try? JSONDecoder().decode(FeeHistory.self, from: data) {
                return data
            } else {
                throw CastError(actualValue: value.value, expectedType: FeeHistory.self)
            }
        case .error(let error):
            throw error
        }
    }
}
