//
//  SuggestEip1559.swift
//  AlphaWallet
//  https://github.com/komputing/KEthereum/blob/master/eip1559_feeOracle/src/main/kotlin/org/kethereum/eip1559_fee_oracle/EIP1559FeeOracle.kt
//  Created by Vladyslav Shepitko on 16.08.2022.
//

import Foundation
import BigInt
import AlphaWalletLogger

actor SuggestEip1559 {
    /// priority fee offered when there are no recent transactions
    private let fallbackPriorityFee: Decimal = 2

    /// effective reward value to be selected from each individual block
    private let rewardPercentile = [10]

    /// suggested priority fee to be selected from sorted individual block reward percentiles
    private let rewardBlockPercentile = 40

    /// highest timeFactor index in the returned list of suggestion
    private let maxTimeFactor: Int = 15

    /// sampled percentile range of exponentially weighted baseFee history
    private let sampleMinPercentile: Double = 10

    private let sampleMaxPercentile: Double = 30

    /// extra priority fee offered in case of expected baseFee rise
    private let extraPriorityFeeRatio = Decimal(0.25)

    let blockchainProvider: BlockchainProvider

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func suggestPriorityFee(feeHistory: FeeHistory) async throws -> Decimal {
        try await suggestPriorityFee(firstBlock: feeHistory.oldestBlock, gasUsedRatio: feeHistory.gasUsedRatio)
    }

    private func suggestPriorityFee(firstBlock: Int, gasUsedRatio: [Double]) async throws -> Decimal {
        var ptr = gasUsedRatio.count - 1
        var needBlocks = 5
        var rewards: [Double] = []
        while needBlocks > 0 && ptr >= 0 {
            let blockCount = maxBlockCount(gasUsedRatio: gasUsedRatio, ptr, needBlocks)
            if blockCount > 0 {
                let lastBlock = firstBlock + Int(ptr)

                let feeHistory = try await blockchainProvider.feeHistory(
                    blockCount: blockCount,
                    block: .blockNumber(value: lastBlock),
                    rewardPercentile: rewardPercentile).first

                let rewardSize = feeHistory.reward.count
                guard !feeHistory.reward.isEmpty else { throw EIP1559Error.rewardsNotFound }
                for reward in feeHistory.reward {
                    let value = reward[0]
                    rewards += [value]
                }
                if rewardSize < blockCount {
                    break
                }
                needBlocks -= blockCount
            }
            ptr -= blockCount + 1
        }

        if rewards.isEmpty {
            return fallbackPriorityFee
        }
        rewards.sort()

        let index = Int(floor(Double((rewards.count - 1) * rewardBlockPercentile) / 100.0))

        return Decimal(rewards[index])
    }

    enum EIP1559Error: Error {
        case baseFeeIsEmpty
        case firstBlockMissing
        case failureToBuildTimedEstimate
        case indexedRewardNotFound
        case rewardsNotFound
        case indexedBaseFeeNotFound
        case minBaseFeeNotFound
    }

    func calculateResult(priorityFee: Decimal, feeHistory: FeeHistory) throws -> [Int: Eip1559FeeOracleResult] {
        var baseFee = feeHistory.baseFeePerGas

        guard !baseFee.isEmpty else { throw EIP1559Error.baseFeeIsEmpty }

        let lastBaseFee = baseFee[baseFee.count - 1] * 1.125
        baseFee[baseFee.count - 1] = lastBaseFee
        for i in feeHistory.gasUsedRatio.indices.reversed() where feeHistory.gasUsedRatio[i] > 0.9 {
            baseFee[i] = baseFee[i + 1]
        }

        let order: [Int] = Array(0 ... feeHistory.gasUsedRatio.count).indices.sorted {
            guard let first = baseFee[safe: $0] else { return false }
            guard let second = baseFee[safe: $1] else { return true }
            return first < second
        }

        var maxBaseFee: Decimal = .zero
        var maxPriorityFee: Decimal = .zero
        var result: [Int: Eip1559FeeOracleResult] = [:]

        for timeFactor in (0...maxTimeFactor).reversed() {
            var bf = try predictMinBaseFee(baseFee: baseFee, order: order, timeFactor: timeFactor)
            var t = priorityFee

            if bf > maxBaseFee {
                maxBaseFee = bf
            } else {
                // If a narrower time window yields a lower base fee suggestion than a wider window then we are probably in a price dip.
                // In this case getting included with a low priority fee is not guaranteed; instead we use the higher base fee suggestion
                // and also offer extra priority fee to increase the chance of getting included in the base fee dip.
                t += (maxBaseFee - bf) * extraPriorityFeeRatio
                bf = maxBaseFee
            }
            //We want the priority fee to be monotonically increasing
            maxPriorityFee = max(maxPriorityFee, t)
            t = maxPriorityFee

            infoLog("[Eip1559] estimate: \(timeFactor) maxFeePerGas: \(bf + t), maxPriorityFeePerGas: \(t)")

            result[timeFactor] = Eip1559FeeOracleResult(
                maxFeePerGas: (bf + t).toBigUInt(units: .gwei)!,
                maxPriorityFeePerGas: t.toBigUInt(units: .gwei)!)
        }

        return result
    }

    private func predictMinBaseFee(baseFee: [Double], order: [Int], timeFactor: Int) throws -> Decimal {
        assert(!baseFee.isEmpty)

        let timeFactor = Double(timeFactor)
        if timeFactor < 1e-6 {
            guard let value = baseFee.last else { throw EIP1559Error.minBaseFeeNotFound }
            return Decimal(value)
        }

        let pendingWeight = (1 - exp(-1 / timeFactor)) / (1 - exp(-Double(baseFee.count) / timeFactor))
        var sumWeight: Double = 0.0
        var result: Double = .zero
        var samplingCurveLast: Double = 0.0

        for each in order {
            sumWeight += pendingWeight * exp(Double(each - baseFee.count + 1) / timeFactor)
            let samplingCurveValue = samplingCurve(percentile: sumWeight * 100.0)

            result += (samplingCurveValue - samplingCurveLast) * baseFee[each]

            if samplingCurveValue >= 1 {
                return Decimal(result)
            }
            samplingCurveLast = samplingCurveValue
        }

        return Decimal(result)
    }

    private func samplingCurve(percentile: Double) -> Double {
        if percentile <= sampleMinPercentile {
            return 0.0
        } else if percentile >= sampleMaxPercentile {
            return 1.0
        } else {
            return Double((1 - cos((percentile - sampleMinPercentile) * 2 * Double.pi / (sampleMaxPercentile - sampleMinPercentile))) / 2)
        }
    }

    private func maxBlockCount(gasUsedRatio: [Double], _ _ptr: Int, _ _needBlocks: Int) -> Int {
        var blockCount = 0
        var ptr = _ptr
        var needBlocks = _needBlocks
        while needBlocks > 0 && ptr >= 0 {
            if gasUsedRatio[ptr] == 0.0 || gasUsedRatio[ptr] > 0.9 {
                break
            }
            ptr -= 1
            needBlocks -= 1
            blockCount += 1
        }
        return blockCount
    }
}

public struct Eip1559FeeOracleResult: Equatable {
    public let maxFeePerGas: BigUInt
    public let maxPriorityFeePerGas: BigUInt

    public init(maxFeePerGas: BigUInt, maxPriorityFeePerGas: BigUInt) {
        self.maxFeePerGas = maxFeePerGas
        self.maxPriorityFeePerGas = maxPriorityFeePerGas
    }
}