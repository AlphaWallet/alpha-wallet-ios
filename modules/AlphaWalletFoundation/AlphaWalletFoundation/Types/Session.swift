// Copyright SIX DAY LLC. All rights reserved.

import Foundation

extension WalletSession {
    public static func == (_ lhs: WalletSession, _ rhs: WalletSession) -> Bool {
        return lhs.server == rhs.server
    }
}

public final class WalletSession: Equatable {
    public let analytics: AnalyticsLogger
    public let account: Wallet
    public let server: RPCServer
    public let config: Config
    public let blockNumberProvider: BlockNumberProvider
    public let tokenProvider: TokenProviderType
    public let importToken: TokenImportable & TokenOrContractFetchable
    public var sessionID: String {
        return WalletSession.functional.sessionID(account: account, server: server)
    }
    public let blockchainProvider: BlockchainProvider
    public let nftProvider: NFTProvider
    public let tokenAdaptor: TokenAdaptor
    public let blockchainExplorer: BlockchainExplorer

    public init(account: Wallet,
                server: RPCServer,
                config: Config,
                analytics: AnalyticsLogger,
                ercTokenProvider: TokenProviderType,
                importToken: TokenImportable & TokenOrContractFetchable,
                blockchainProvider: BlockchainProvider,
                nftProvider: NFTProvider,
                tokenAdaptor: TokenAdaptor,
                blockchainExplorer: BlockchainExplorer) {

        self.blockchainExplorer = blockchainExplorer
        self.tokenAdaptor = tokenAdaptor
        self.nftProvider = nftProvider
        self.analytics = analytics
        self.account = account
        self.server = server
        self.config = config
        self.importToken = importToken
        self.tokenProvider = ercTokenProvider
        self.blockchainProvider = blockchainProvider
        self.blockNumberProvider = BlockNumberProvider(storage: config, blockchainProvider: blockchainProvider)

        if config.development.isAutoFetchingDisabled {
            //no-op
        } else {
            self.blockNumberProvider.start()
        }
    }

    deinit {
        blockNumberProvider.cancel()
    }
}

extension WalletSession {
    public enum functional {}
}

extension WalletSession.functional {
    public static func sessionID(account: Wallet, server: RPCServer) -> String {
        return "\(account.address.eip55String.lowercased())-\(server.chainID)"
    }
}
