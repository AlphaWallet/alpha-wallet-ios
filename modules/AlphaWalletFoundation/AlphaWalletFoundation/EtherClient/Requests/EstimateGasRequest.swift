// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import JSONRPCKit
import BigInt

enum EstimateGasTransactionType {
    case normal(to: AlphaWallet.Address)
    case contractDeployment

    var contract: AlphaWallet.Address? {
        switch self {
        case .normal(let to):
            return to
        case .contractDeployment:
            return nil
        }
    }

    var canCapGasLimit: Bool {
        switch self {
        case .normal:
            return true
        case .contractDeployment:
            return false
        }
    }
}

struct EstimateGasRequest: JSONRPCKit.Request {
    typealias Response = BigUInt

    let from: AlphaWallet.Address
    let transactionType: EstimateGasTransactionType
    let value: BigUInt
    let data: Data

    var method: String {
        return "eth_estimateGas"
    }

    var parameters: Any? {
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
        return results
    }

    func response(from resultObject: Any) throws -> Response {
        if let response = resultObject as? String, let value = BigUInt(response.drop0x, radix: 16) {
            return value
        } else {
            throw CastError(actualValue: resultObject, expectedType: Response.self)
        }
    }
}
