// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct ConfigExplorer {
    private let server: RPCServer

    init(server: RPCServer) {
        self.server = server
    }

    func transactionUrl(for ID: String) -> (url: URL, name: String)? {
        let result = ConfigExplorer.explorer(for: server)
        return result.url
            .flatMap { URL(string: $0 + "/tx/" + ID) }
            .flatMap { (url: $0, name: result.name) }
    }

    func contractUrl(address: AlphaWallet.Address) -> (url: URL, name: String)? {
        let result = ConfigExplorer.explorer(for: server)
        return result.url
            .flatMap { URL(string: $0 + "/address/" + address.eip55String) }
            .flatMap { (url: $0, name: result.name) }
    }

    private static func explorerName(for server: RPCServer) -> String {
        switch server {
        case .main, .kovan, .ropsten, .rinkeby, .goerli:
            return "Etherscan"
        case .classic, .poa, .custom, .callisto, .sokol, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet:
            return "\(server.name) Explorer"
        case .xDai:
            return "Blockscout"
        case .artis_sigma1, .artis_tau1:
            return "ARTIS"
        }
    }

    private static func explorer(for server: RPCServer) -> (url: String?, name: String) {
        let nameForServer = explorerName(for: server)
        let url = server.etherscanWebpageRoot
        return (url?.absoluteString, nameForServer)
    }
}
