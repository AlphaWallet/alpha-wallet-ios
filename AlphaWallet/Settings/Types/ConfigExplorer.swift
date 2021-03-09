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
            case .poa:
                return endpoint + "/txid/search/" + ID
            case .custom, .callisto:
                return .none
            case .main, .kovan, .ropsten, .rinkeby, .sokol, .classic, .xDai, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet:
                return endpoint + "/tx/" + ID
            case .taiChi:
                return endpoint + "/txscan/priTx?txHash=" + ID
            }
        }()
        guard let string = urlString, let url = URL(string: string) else { return .none }

        return (url: url, name: result.name)
    }

    func explorerName(for server: RPCServer) -> String? {
        switch server {
        case .main, .kovan, .ropsten, .rinkeby, .goerli:
            return "Etherscan"
        case .classic:
            return "ETC Explorer"
        case .poa:
            return "POA Explorer"
        case .custom, .callisto:
            return nil
        case .sokol:
            return "Sokol Explorer"
        case .xDai:
            return "Blockscout"
        case .binance_smart_chain, .binance_smart_chain_testnet:
            return "Binance Explorer"
        case .artis_sigma1, .artis_tau1:
            return "ARTIS"
        case .heco, .heco_testnet:
            return "Heco Explorer"
        case .taiChi:
            return "TaiChi"
        }
    }

    private func explorer(for server: RPCServer) -> (url: String?, name: String?) {
        let nameForServer = explorerName(for: server)
        switch server {
        case .main:
            return ("https://cn.etherscan.com", nameForServer)
        case .classic:
            return ("https://blockscout.com/etc/mainnet/", nameForServer)
        case .kovan:
            return ("https://kovan.etherscan.io", nameForServer)
        case .ropsten:
            return ("https://ropsten.etherscan.io", nameForServer)
        case .rinkeby:
            return ("https://rinkeby.etherscan.io", nameForServer)
        case .poa:
            return ("https://poaexplorer.com", nameForServer)
        case .sokol:
            return ("https://sokol-explorer.poa.network", nameForServer)
        case .xDai:
            return ("https://blockscout.com/poa/dai/", nameForServer)
        case .goerli:
            return ("https://goerli.etherscan.io", nameForServer)
        case .artis_sigma1:
            return ("https://explorer.sigma1.artis.network", nameForServer)
        case .artis_tau1:
            return ("https://explorer.tau1.artis.network", nameForServer)
        case .binance_smart_chain:
            return ("https://api.bscscan.com", nameForServer)
        case .binance_smart_chain_testnet:
            return ("https://api-testnet.bscscan.com", nameForServer)
        case .custom, .callisto:
            return (.none, nameForServer)
        case .heco:
            return ("https://scan.hecochain.com", nameForServer)
        case .heco_testnet:
            return ("https://scan-testnet.hecochain.com", nameForServer)
        case .taiChi:
            return ("https://api.taichi.network:10001", nameForServer)
        }
    }
}
