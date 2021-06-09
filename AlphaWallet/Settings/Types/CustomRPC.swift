// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct CustomRPC: Codable, Hashable {
    let chainID: Int
    let nativeCryptoTokenName: String?
    let chainName: String
    let symbol: String?
    let rpcEndpoint: String
    let explorerEndpoint: String?
    let etherscanCompatibleType: RPCServer.EtherscanCompatibleType
    let isTestnet: Bool
}