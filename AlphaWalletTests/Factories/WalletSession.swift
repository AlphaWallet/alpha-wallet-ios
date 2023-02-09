// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import AlphaWalletFoundation

extension WalletSession {
    static func make(account: Wallet = .make(), server: RPCServer = .main, config: Config = .make(), analytics: AnalyticsLogger = FakeAnalyticsService()) -> WalletSession {
        let blockchainProvider = RpcBlockchainProvider(server: server, analytics: analytics, params: .defaultParams(for: server))
        let ercTokenProvider = TokenProvider(account: account, blockchainProvider: blockchainProvider)
        let importToken: ImportToken = .make(server: server)
        return WalletSession(account: account, server: server, config: config, analytics: analytics, ercTokenProvider: ercTokenProvider, importToken: importToken, blockchainProvider: blockchainProvider, nftProvider: FakeNftProvider())
    }

    static func make(account: Wallet = .make(), server: RPCServer = .main, config: Config = .make(), analytics: AnalyticsLogger = FakeAnalyticsService(), importToken: TokenImportable & TokenOrContractFetchable) -> WalletSession {
        let blockchainProvider = RpcBlockchainProvider(server: server, analytics: analytics, params: .defaultParams(for: server))
        let ercTokenProvider = TokenProvider(account: account, blockchainProvider: blockchainProvider)
        return WalletSession(account: account, server: server, config: config, analytics: analytics, ercTokenProvider: ercTokenProvider, importToken: importToken, blockchainProvider: blockchainProvider, nftProvider: FakeNftProvider())
    }

    static func makeStormBirdSession(account: Wallet = .makeStormBird(), server: RPCServer, config: Config = .make(), analytics: AnalyticsLogger = FakeAnalyticsService()) -> WalletSession {
        let blockchainProvider = RpcBlockchainProvider(server: server, analytics: analytics, params: .defaultParams(for: server))
        let ercTokenProvider = TokenProvider(account: account, blockchainProvider: blockchainProvider)
        let importToken: ImportToken = .make(server: server)
        
        return WalletSession(account: account, server: server, config: config, analytics: analytics, ercTokenProvider: ercTokenProvider, importToken: importToken, blockchainProvider: blockchainProvider, nftProvider: FakeNftProvider())
    }
}
