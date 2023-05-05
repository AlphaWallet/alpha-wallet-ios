// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import BigInt

public struct GasPriceConfiguration {
    public static let defaultPrice: BigUInt = BigUInt(EtherNumberFormatter.full.number(from: "9", units: UnitConfiguration.gasPriceUnit)!)
    public static let minPrice: BigUInt = BigUInt(EtherNumberFormatter.full.number(from: "1", units: UnitConfiguration.gasPriceUnit)!)
    public static let oneGwei: BigUInt = BigUInt(EtherNumberFormatter.full.number(from: "1", units: UnitConfiguration.gasPriceUnit)!)
    public static let maxPrice: BigUInt = BigUInt(EtherNumberFormatter.full.number(from: "700", units: UnitConfiguration.gasPriceUnit)!)
    public static let xDaiGasPrice: BigUInt = BigUInt(EtherNumberFormatter.full.number(from: "2", units: UnitConfiguration.gasPriceUnit)!)
    public static let klaytnMaxPrice: BigUInt = BigUInt(EtherNumberFormatter.full.number(from: "750", units: UnitConfiguration.gasPriceUnit)!)
}

extension GasPriceConfiguration {
    public static func defaultPrice(forServer server: RPCServer) -> BigUInt {
        switch server.serverWithEnhancedSupport {
        case .klaytnCypress, .klaytnBaobabTestnet:
            return GasPriceConfiguration.klaytnMaxPrice
        case .main, .xDai, .polygon, .binance_smart_chain, .heco, .rinkeby, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, nil:
            return GasPriceConfiguration.defaultPrice
        }
    }

    public static func maxPrice(forServer server: RPCServer) -> BigUInt {
        switch server.serverWithEnhancedSupport {
        case .klaytnCypress, .klaytnBaobabTestnet:
            return GasPriceConfiguration.klaytnMaxPrice
        case .main, .xDai, .polygon, .binance_smart_chain, .heco, .rinkeby, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, nil:
            return GasPriceConfiguration.maxPrice
        }
    }

    public static func gasPriceBuffer(server: RPCServer) -> GasPriceBuffer {
        switch server.serverWithEnhancedSupport {
        case .xDai:
            return GasPriceBuffer.percentage(10)
        case .main, .klaytnCypress, .klaytnBaobabTestnet, .polygon, .binance_smart_chain, .heco, .rinkeby, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, nil:
            return GasPriceBuffer.fixed(GasPriceConfiguration.oneGwei)
        }
    }
}
