//
//  FeeHistory.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.08.2022.
//

import Foundation
import AlphaWalletCore
import BigInt

public struct FeeHistory {
    let baseFeePerGas: [Double]
    let gasUsedRatio: [Double]
    let oldestBlock: Int
    let reward: [[Double]]
}

extension FeeHistory: Codable {
    enum CodingKeys: String, CodingKey {
        case baseFeePerGas
        case gasUsedRatio
        case oldestBlock
        case reward
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        baseFeePerGas = try container.decode([String].self, forKey: .baseFeePerGas).compactMap {
            guard let value = BigUInt($0.drop0x, radix: 16) else { return nil }
            return Decimal(bigUInt: value, decimals: EthereumUnit.gwei.decimals)?.doubleValue
        }
        gasUsedRatio = try container.decode([Double].self, forKey: .gasUsedRatio)
        let oldestBlockString = try container.decode(String.self, forKey: .oldestBlock)
        guard let _oldestBlock = Int(oldestBlockString.drop0x, radix: 16) else {
            throw CastError(actualValue: oldestBlockString, expectedType: Int.self)
        }
        oldestBlock = _oldestBlock
        reward = container.decode([[String]].self, forKey: .reward, defaultValue: []).map {
            $0.compactMap {
                guard let value = BigUInt($0.drop0x, radix: 16) else { return nil }
                return Decimal(bigUInt: value, decimals: EthereumUnit.gwei.decimals)?.doubleValue
            }
        }
    }
}
