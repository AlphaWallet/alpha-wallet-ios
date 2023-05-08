// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public struct CustomRPC: Codable, Hashable {
    public let chainID: Int
    public let nativeCryptoTokenName: String?
    public let chainName: String
    public let symbol: String?
    public let rpcEndpoint: String
    public let explorerEndpoint: String?
    public let etherscanCompatibleType: RPCServer.EtherscanCompatibleType
    public let isTestnet: Bool

    public static func custom(chainId: Int) -> CustomRPC {
        return .init(chainID: chainId, nativeCryptoTokenName: nil, chainName: "", symbol: nil, rpcEndpoint: "", explorerEndpoint: "", etherscanCompatibleType: .unknown, isTestnet: false)
    }
}
