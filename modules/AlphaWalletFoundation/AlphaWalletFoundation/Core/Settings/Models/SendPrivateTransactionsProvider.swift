// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

public enum SendPrivateTransactionsProvider: String {
    case ethermine
    case eden

    public func rpcUrl(forServer server: RPCServer) -> URL? {
        switch self {
        case .ethermine:
            switch server {
            case .main: return URL(string: "https://rpc.ethermine.org")!
            case .xDai, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .phi: return nil
            case .klaytnCypress, .klaytnBaobabTestnet: return nil
            case .ioTeX, .ioTeXTestnet: return nil
            }
        case .eden:
            switch server {
            case .main: return URL(string: "https://api.edennetwork.io/v1/rpc")!
            case .ropsten: return URL(string: "https://dev-api.edennetwork.io/v1/rpc")!
            case .xDai, .kovan, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .phi: return nil
            case .klaytnCypress, .klaytnBaobabTestnet: return nil
            case .ioTeX, .ioTeXTestnet: return nil
            }
        }
    }
}
