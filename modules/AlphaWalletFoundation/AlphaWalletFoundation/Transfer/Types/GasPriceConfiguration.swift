// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import BigInt

public struct GasPriceConfiguration {
    public static let defaultPrice: BigInt = EtherNumberFormatter.full.number(from: "9", units: UnitConfiguration.gasPriceUnit)!
    public static let minPrice: BigInt = EtherNumberFormatter.full.number(from: "1", units: UnitConfiguration.gasPriceUnit)!
    public static let oneGwei: BigInt = EtherNumberFormatter.full.number(from: "1", units: UnitConfiguration.gasPriceUnit)!
    public static let maxPrice: BigInt = EtherNumberFormatter.full.number(from: "700", units: UnitConfiguration.gasPriceUnit)!
    public static let xDaiGasPrice: BigInt = EtherNumberFormatter.full.number(from: "1", units: UnitConfiguration.gasPriceUnit)!
    public static let klaytnMaxPrice: BigInt = EtherNumberFormatter.full.number(from: "750", units: UnitConfiguration.gasPriceUnit)!
}

extension GasPriceConfiguration {
    public static func defaultPrice(forServer server: RPCServer) -> BigInt {
        switch server.serverWithEnhancedSupport {
        case .klaytnCypress, .klaytnBaobabTestnet:
            return GasPriceConfiguration.klaytnMaxPrice
        case .main, .xDai, .candle, .polygon, .binance_smart_chain, .heco, .rinkeby, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, nil:
            return GasPriceConfiguration.defaultPrice
        }
    }

    public static func maxPrice(forServer server: RPCServer) -> BigInt {
        switch server.serverWithEnhancedSupport {
        case .klaytnCypress, .klaytnBaobabTestnet:
            return GasPriceConfiguration.klaytnMaxPrice
        case .main, .xDai, .candle, .polygon, .binance_smart_chain, .heco, .rinkeby, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, nil:
            return GasPriceConfiguration.maxPrice
        }
    }
}
