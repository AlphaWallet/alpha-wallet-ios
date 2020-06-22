// Copyright SIX DAY LLC. All rights reserved.
//This struct sets the amount of gas units to consume
import Foundation
import BigInt

public struct GasLimitConfiguration {
    static let defaultGasLimit = BigInt(90_000)
    static let minGasLimit = BigInt(21_000) // ETH transfers are always 21k
    static let maxGasLimit = BigInt(1_000_000)
}
