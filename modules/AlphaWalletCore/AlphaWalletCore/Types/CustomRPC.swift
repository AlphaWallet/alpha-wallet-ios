// Copyright © 2023 Stormbird PTE. LTD.

public struct CustomRPC: Codable, Hashable {
    public let chainID: Int
    public let nativeCryptoTokenName: String?
    public let chainName: String
    public let symbol: String?
    public let rpcEndpoint: String
    public let explorerEndpoint: String?
    public let etherscanCompatibleType: RPCServer.EtherscanCompatibleType
    public let isTestnet: Bool

    public init(chainID: Int, nativeCryptoTokenName: String?, chainName: String, symbol: String?, rpcEndpoint: String, explorerEndpoint: String?, etherscanCompatibleType: RPCServer.EtherscanCompatibleType, isTestnet: Bool) {
        self.chainID = chainID
        self.nativeCryptoTokenName = nativeCryptoTokenName
        self.chainName = chainName
        self.symbol = symbol
        self.rpcEndpoint = rpcEndpoint
        self.explorerEndpoint = explorerEndpoint
        self.etherscanCompatibleType = etherscanCompatibleType
        self.isTestnet = isTestnet
    }

    public static func custom(chainId: Int) -> CustomRPC {
        return .init(chainID: chainId, nativeCryptoTokenName: nil, chainName: "", symbol: nil, rpcEndpoint: "", explorerEndpoint: "", etherscanCompatibleType: .unknown, isTestnet: false)
    }
}
