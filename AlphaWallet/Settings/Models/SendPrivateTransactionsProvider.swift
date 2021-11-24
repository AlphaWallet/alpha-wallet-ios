// Copyright © 2021 Stormbird PTE. LTD.

import UIKit

enum SendPrivateTransactionsProvider: String {
    case ethermine
    case eden

    var title: String {
        switch self {
        case .ethermine:
            return R.string.localizable.sendPrivateTransactionsProviderEtheremine()
        case .eden:
            return R.string.localizable.sendPrivateTransactionsProviderEden()
        }
    }

    var icon: UIImage {
        switch self {
        case .ethermine:
            return R.image.iconsSettingsEthermine()!
        case .eden:
            return R.image.iconsSettingsEden()!
        }
    }

    func rpcUrl(forServer server: RPCServer) -> URL? {
        switch self {
        case .ethermine:
            switch server {
            case .main:
                return URL(string: "https://rpc.ethermine.org")!
            case .xDai, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .palm, .palmTestnet:
                return nil
            }
        case .eden:
            switch server {
            case .main:
                return URL(string: "https://api.edennetwork.io/v1/rpc")!
            case .ropsten:
                return URL(string: "https://dev-api.edennetwork.io/v1/rpc")!
            case .xDai, .kovan, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .palm, .palmTestnet:
                return nil
            }
        }
    }
}