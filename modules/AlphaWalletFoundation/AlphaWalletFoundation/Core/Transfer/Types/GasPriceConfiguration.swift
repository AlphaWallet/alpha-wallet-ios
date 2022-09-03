// Copyright © 2021 Stormbird PTE. LTD.
// This struct sets the price for each unit of gas

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
        switch server {
        case .klaytnCypress, .klaytnBaobabTestnet:
            return GasPriceConfiguration.klaytnMaxPrice
        case .main, .rinkeby, .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .custom, .goerli, .xDai, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .phi, .ioTeX, .ioTeXTestnet:
            return GasPriceConfiguration.defaultPrice
        }
    }

    public static func maxPrice(forServer server: RPCServer) -> BigInt {
        switch server {
        case .klaytnCypress, .klaytnBaobabTestnet:
            return GasPriceConfiguration.klaytnMaxPrice
        case .main, .rinkeby, .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .custom, .goerli, .xDai, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .phi, .ioTeX, .ioTeXTestnet:
            return GasPriceConfiguration.maxPrice
        }
    }
}
