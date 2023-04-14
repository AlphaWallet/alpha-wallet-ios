// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt

public protocol GasEstimates {
    subscript(gasSpeed: GasSpeed) -> GasPrice? { get }
}

public struct LegacyGasEstimates: GasEstimates {
    public var standard: BigUInt
    public var keys: [GasSpeed] {
        others.keys.map { $0 }
    }

    private var others: [GasSpeed: BigUInt]

    public subscript(gasSpeed: GasSpeed) -> GasPrice? {
        switch gasSpeed {
        case .standard:
            return .legacy(gasPrice: standard)
        case .fast, .rapid, .slow:
            return others[gasSpeed].flatMap { GasPrice.legacy(gasPrice: $0) }
        case .custom:
            return nil
        }
    }

    public init(standard: BigUInt, others: [GasSpeed: BigUInt] = .init()) {
        self.others = others
        self.standard = standard
    }

    public var fastest: BigUInt? {
        for each in GasSpeed.sortedThirdPartyFastestFirst {
            if let config = others[each] {
                return config
            }
        }
        return nil
    }

    public var slowest: BigUInt? {
        for each in GasSpeed.sortedThirdPartyFastestFirst.reversed() {
            if let config = others[each] {
                return config
            }
        }
        return nil
    }
}

public struct Eip1559FeeEstimates: GasEstimates {
    public var estimates: [GasSpeed: Eip1559FeeOracleResult]
    public init(estimates: [GasSpeed: Eip1559FeeOracleResult]) {
        self.estimates = estimates
    }

    public subscript(gasSpeed: GasSpeed) -> GasPrice? {
        estimates[gasSpeed].flatMap { GasPrice.eip1559(maxFeePerGas: $0.maxFeePerGas, maxPriorityFeePerGas: $0.maxPriorityFeePerGas) }
    }

    public var fastest: Eip1559FeeOracleResult? {
        for each in GasSpeed.sortedThirdPartyFastestFirst {
            if let config = estimates[each] {
                return config
            }
        }
        return nil
    }

    public var slowest: Eip1559FeeOracleResult? {
        for each in GasSpeed.sortedThirdPartyFastestFirst.reversed() {
            if let config = estimates[each] {
                return config
            }
        }
        return nil
    }
}
