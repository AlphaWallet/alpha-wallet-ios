//
//  BlockchainParams.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 20.01.2023.
//

import Foundation
import BigInt

public struct BlockchainParams {
    public let maxGasLimit: BigUInt
    public let maxPrice: BigUInt
    public let gasPriceBuffer: GasPriceBuffer
    public let minGasLimit: BigUInt
    public let defaultPrice: BigUInt
    public let chainId: Int
    public let canUserChangeGas: Bool
    public let shouldAddBufferWhenEstimatingGasPrice: Bool

    public static func defaultParams(for server: RPCServer) -> BlockchainParams {
        return .init(
            maxGasLimit: GasLimitConfiguration.maxGasLimit(forServer: server),
            maxPrice: GasPriceConfiguration.maxPrice(forServer: server),
            gasPriceBuffer: GasPriceConfiguration.gasPriceBuffer(server: server),
            minGasLimit: GasLimitConfiguration.minGasLimit,
            defaultPrice: GasPriceConfiguration.defaultPrice(forServer: server),
            chainId: server.chainID,
            canUserChangeGas: server.canUserChangeGas,
            shouldAddBufferWhenEstimatingGasPrice: server.shouldAddBufferWhenEstimatingGasPrice)
    }
}
