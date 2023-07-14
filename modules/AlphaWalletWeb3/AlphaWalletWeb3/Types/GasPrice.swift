//
//  GasPrice.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 14.02.2023.
//

import BigInt

public enum GasPrice: Hashable, Equatable, Codable {
    case legacy(gasPrice: BigUInt)
    case eip1559(maxFeePerGas: BigUInt, maxPriorityFeePerGas: BigUInt)

    public var max: BigUInt {
        switch self {
        case .legacy(let gasPrice): return gasPrice
        case .eip1559(let maxFeePerGas, _): return maxFeePerGas
        }
    }

    enum LegacyCodingKeys: CodingKey {
        case gasPrice
    }

    enum Eip1559CodingKeys: CodingKey {
        case maxFeePerGas
        case maxPriorityFeePerGas
    }

    public init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: LegacyCodingKeys.self)
            let gasPriceString = try container.decode(String.self, forKey: .gasPrice)

            let gasPrice = BigUInt(gasPriceString.drop0x, radix: 16) ?? .zero

            self = .legacy(gasPrice: gasPrice)
        } catch {
            let container = try decoder.container(keyedBy: Eip1559CodingKeys.self)
            let maxFeePerGasString = try container.decode(String.self, forKey: .maxFeePerGas)
            let maxPriorityFeePerGasString = try container.decode(String.self, forKey: .maxPriorityFeePerGas)

            let maxFeePerGas = BigUInt(maxFeePerGasString.drop0x, radix: 16) ?? .zero
            let maxPriorityFeePerGas = BigUInt(maxPriorityFeePerGasString.drop0x, radix: 16) ?? .zero

            self = .eip1559(maxFeePerGas: maxFeePerGas, maxPriorityFeePerGas: maxPriorityFeePerGas)
        }
    }
}

extension GasPrice: CustomStringConvertible {

    public var description: String {
        switch self {
        case .legacy(let gasPrice): return "Legacy(\(gasPrice))"
        case .eip1559(let maxFeePerGas, let maxPriorityFeePerGas): return "EIP1559(\(maxFeePerGas),\(maxPriorityFeePerGas))"
        }
    }
}
