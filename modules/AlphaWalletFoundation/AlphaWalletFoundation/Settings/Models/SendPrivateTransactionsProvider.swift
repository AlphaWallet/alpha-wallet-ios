// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

public enum SendPrivateTransactionsProvider: String, CaseIterable {
    case ethermine
    case eden

    public func rpcUrl(forServer server: RPCServer) -> URL? {
        switch self {
        case .ethermine:
            switch server.serverWithEnhancedSupport {
            case .main:
                return URL(string: "https://rpc.ethermine.org")!
            case .xDai, .polygon, .binance_smart_chain, .heco, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, .rinkeby, nil:
                return nil
            }
        case .eden:
            switch server.serverWithEnhancedSupport {
            case .main:
                return URL(string: "https://api.edennetwork.io/v1/rpc")!
            case .xDai, .polygon, .binance_smart_chain, .heco, .rinkeby, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, nil:
                return nil
            }
        }
    }
}
