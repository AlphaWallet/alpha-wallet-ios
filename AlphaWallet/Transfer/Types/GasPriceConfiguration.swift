// Copyright © 2021 Stormbird PTE. LTD.
// This struct sets the price for each unit of gas

import Foundation
import BigInt

public struct GasPriceConfiguration {
    static let defaultPrice: BigInt = EtherNumberFormatter.full.number(from: "9", units: UnitConfiguration.gasPriceUnit)!
    static let minPrice: BigInt = EtherNumberFormatter.full.number(from: "1", units: UnitConfiguration.gasPriceUnit)!
    static let oneGwei: BigInt = EtherNumberFormatter.full.number(from: "1", units: UnitConfiguration.gasPriceUnit)!
    static let maxPrice: BigInt = EtherNumberFormatter.full.number(from: "700", units: UnitConfiguration.gasPriceUnit)!
    static let xDaiGasPrice: BigInt = EtherNumberFormatter.full.number(from: "1", units: UnitConfiguration.gasPriceUnit)!
    static let klaytnMaxPrice: BigInt = EtherNumberFormatter.full.number(from: "750", units: UnitConfiguration.gasPriceUnit)!
}

extension GasPriceConfiguration {
    static func defaultPrice(forServer server: RPCServer) -> BigInt {
        switch server {
        case .klaytnCypress, .klaytnBaobabTestnet:
            return GasPriceConfiguration.klaytnMaxPrice
        case .main, .rinkeby, .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .custom, .goerli, .xDai, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .phi:
            return GasPriceConfiguration.defaultPrice
        }
    }

    static func maxPrice(forServer server: RPCServer) -> BigInt {
        switch server {
        case .klaytnCypress, .klaytnBaobabTestnet:
            return GasPriceConfiguration.klaytnMaxPrice
        case .main, .rinkeby, .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .custom, .goerli, .xDai, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .phi:
            return GasPriceConfiguration.maxPrice
        }
    }
}
