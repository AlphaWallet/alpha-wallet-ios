// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct ConfigExplorer {
    private let server: RPCServer

    init(
        server: RPCServer
    ) {
        self.server = server
    }

    func transactionURL(for ID: String) -> (url: URL, name: String?)? {
        let result = explorer(for: server)
        guard let endpoint = result.url else { return .none }
        let urlString: String? = {
            switch server {
            case .main, .kovan, .ropsten, .rinkeby, .sokol, .classic, .xDai, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .callisto, .poa, .custom:
                return endpoint + "/tx/" + ID
            }
        }()
        guard let string = urlString, let url = URL(string: string) else { return .none }

        return (url: url, name: result.name)
    }

    func explorerName(for server: RPCServer) -> String? {
        switch server {
        case .main, .kovan, .ropsten, .rinkeby, .goerli:
            return "Etherscan"
        case .classic, .poa, .custom, .callisto, .sokol, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan:
            return "\(server.name) Explorer"
        case .xDai:
            return "Blockscout"
        case .artis_sigma1, .artis_tau1:
            return "ARTIS"
        }
    }

    private func explorer(for server: RPCServer) -> (url: String?, name: String?) {
        let nameForServer = explorerName(for: server)
        let url = server.etherscanWebpageRoot
        return (url?.absoluteString, nameForServer)
    }
}
