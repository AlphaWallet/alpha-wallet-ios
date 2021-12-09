// Copyright SIX DAY LLC. All rights reserved.
//This struct sets the amount of gas units to consume
import Foundation
import BigInt

public struct GasLimitConfiguration {
    static let defaultGasLimit = BigInt(90_000)
    static let minGasLimit = BigInt(21_000)
    //TODO make max be 1M unless for contract deployment then bigger, maybe 2M
    static let maxGasLimit = BigInt(2_000_000)
}