//
//  GetFeeHistory.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 16.08.2022.
//

import Combine
import Foundation
import AlphaWalletCore
import APIKit
import JSONRPCKit

struct FeeHistoryRequest: JSONRPCKit.Request {
    typealias Response = FeeHistory

    let blockCount: Int
    let lastBlock: String
    let rewardPercentile: [Int]

    var method: String {
        return "eth_feeHistory"
    }

    var parameters: Any? {
        return [blockCount, lastBlock, rewardPercentile]
    }

    func response(from resultObject: Any) throws -> Response {
        guard let data = try? JSONSerialization.data(withJSONObject: resultObject, options: []) else {
            throw CastError(actualValue: resultObject, expectedType: Response.self)
        }
        if let data = try? JSONDecoder().decode(Response.self, from: data) {
            return data
        } else {
            throw CastError(actualValue: resultObject, expectedType: Response.self)
        }
    }
}

