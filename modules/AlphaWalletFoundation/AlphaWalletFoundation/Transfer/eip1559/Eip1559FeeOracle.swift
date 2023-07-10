//
//  Eip1559FeeOracle.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 16.08.2022.
//

import Foundation
import Combine
import AlphaWalletWeb3
import BigInt

class Eip1559FeeOracle {
    private let suggestEip1559: SuggestEip1559
    private let blockchainProvider: BlockchainProvider

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
        self.suggestEip1559 = SuggestEip1559(blockchainProvider: blockchainProvider)
    }

    func eip1559FeeEstimates(blockCount: Int = 100, block: BlockParameter = .latest, rewardPercentile: [Int] = []) async throws -> Eip1559FeeEstimates {
        do {
            let feeHistory = try await blockchainProvider.feeHistory(blockCount: blockCount, block: block, rewardPercentile: rewardPercentile).first
            let priorityFee = try await suggestEip1559.suggestPriorityFee(feeHistory: feeHistory)
            let elems = try await suggestEip1559.calculateResult(priorityFee: priorityFee, feeHistory: feeHistory)

            var estimates: [GasSpeed: Eip1559FeeOracleResult] = [:]

            let third = elems.count / 3

            estimates[.rapid] = elems[0]
            estimates[.fast] = elems[third]
            estimates[.standard] = elems[third * 2]
            estimates[.slow] = elems[elems.count - 1]

            return Eip1559FeeEstimates(estimates: estimates)
        } catch {
            throw SessionTaskError(error: error)
        }
    }
}
