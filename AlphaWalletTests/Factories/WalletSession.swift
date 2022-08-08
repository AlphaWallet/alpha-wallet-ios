// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet

extension WalletSession {
    static func make(
        account: Wallet = .make(),
        server: RPCServer = .main,
        config: Config = .make(),
        tokenBalanceService: TokenBalanceService,
        analytics: AnalyticsLogger = FakeAnalyticsService()
    ) -> WalletSession {
        return WalletSession(
            account: account,
            server: server,
            config: config,
            tokenBalanceService: tokenBalanceService,
            analytics: analytics
        )
    }

    static func make(
        account: Wallet = .make(),
        server: RPCServer = .main,
        config: Config = .make(),
        analytics: AnalyticsLogger = FakeAnalyticsService()
    ) -> WalletSession {
        let tokenBalanceService = FakeSingleChainTokenBalanceService(wallet: account, server: server, etherToken: Token(contract: AlphaWallet.Address.make(), server: server, value: "0", type: .nativeCryptocurrency))
        return WalletSession(
            account: account,
            server: server,
            config: config,
            tokenBalanceService: tokenBalanceService,
            analytics: analytics
        )
    }

    static func makeStormBirdSession(
        account: Wallet = .makeStormBird(),
        server: RPCServer,
        config: Config = .make(),
        tokenBalanceService: TokenBalanceService,
        analytics: AnalyticsLogger = FakeAnalyticsService()
    ) -> WalletSession {
        let tokenBalanceService = FakeSingleChainTokenBalanceService(wallet: account, server: server, etherToken: Token(contract: AlphaWallet.Address.make(), server: server, value: "0", type: .nativeCryptocurrency))
        return WalletSession(
            account: account,
            server: server,
            config: config,
            tokenBalanceService: tokenBalanceService,
            analytics: analytics
        )
    }
}
