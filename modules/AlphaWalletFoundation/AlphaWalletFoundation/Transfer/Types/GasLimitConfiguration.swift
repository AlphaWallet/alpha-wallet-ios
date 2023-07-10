// Copyright SIX DAY LLC. All rights reserved.
//This struct sets the amount of gas units to consume
import Foundation
import BigInt
import AlphaWalletCore

public struct GasLimitConfiguration {
    public static let defaultGasLimit = BigUInt(90_000)
    public static let minGasLimit = BigUInt(21_000)
    public static func maxGasLimit(forServer server: RPCServer) -> BigUInt {
        switch server.serverWithEnhancedSupport {
        case .klaytnCypress, .klaytnBaobabTestnet:
            return BigUInt(100_000_000)
        case .main, .xDai, .polygon, .binance_smart_chain, .heco, .rinkeby, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, nil:
            //TODO make max be 1M unless for contract deployment then bigger, maybe 2M
            return BigUInt(2_000_000)
        }
    }
}
