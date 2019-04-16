// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct ConfigExplorer {
    private let server: RPCServer

    init(
        server: RPCServer
    ) {
        self.server = server
    }

    func transactionURL(for ID: String) -> URL? {
        guard let endpoint = explorer(for: server) else { return .none }
        let urlString: String? = {
            switch server {
            case .poa:
                return endpoint + "/txid/search/" + ID
            case .custom, .callisto:
                return .none
            default:
                return endpoint + "/tx/" + ID
            }
        }()
        guard let string = urlString else { return .none }
        return URL(string: string)!
    }

    private func explorer(for server: RPCServer) -> String? {
        switch server {
        case .main:
            return "https://etherscan.io"
        case .classic:
            return "https://gastracker.io"
        case .kovan:
            return "https://kovan.etherscan.io"
        case .ropsten:
            return "https://ropsten.etherscan.io"
        case .rinkeby:
            return "https://rinkeby.etherscan.io"
        case .poa:
            return "https://poaexplorer.com"
        case .sokol:
            return "https://sokol-explorer.poa.network"
        case .xDai:
            return "https://blockscout.com/poa/dai/"
        case .goerli:
            return "https://goerli.etherscan.io"
        case .custom, .callisto:
            return .none
        }
    }
}
