// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet

extension WalletSession {
    static func make(
        account: Wallet = .make(),
        server: RPCServer = .main,
        config: Config = .make(),
        tokenBalanceService: TokenBalanceService,
        analyticsCoordinator: AnalyticsCoordinator = FakeAnalyticsService()
    ) -> WalletSession {
        return WalletSession(
            account: account,
            server: server,
            config: config,
            tokenBalanceService: tokenBalanceService,
            analyticsCoordinator: analyticsCoordinator
        )
    }

    static func make(
        account: Wallet = .make(),
        server: RPCServer = .main,
        config: Config = .make(),
        analyticsCoordinator: AnalyticsCoordinator = FakeAnalyticsService()
    ) -> WalletSession {
        let tokenBalanceService = FakeSingleChainTokenBalanceService(wallet: account, server: server, etherToken: Token(contract: AlphaWallet.Address.make(), server: server, value: "0", type: .nativeCryptocurrency))
        return WalletSession(
            account: account,
            server: server,
            config: config,
            tokenBalanceService: tokenBalanceService,
            analyticsCoordinator: analyticsCoordinator
        )
    }

    static func makeStormBirdSession(
        account: Wallet = .makeStormBird(),
        server: RPCServer,
        config: Config = .make(),
        tokenBalanceService: TokenBalanceService,
        analyticsCoordinator: AnalyticsCoordinator = FakeAnalyticsService()
    ) -> WalletSession {
        let tokenBalanceService = FakeSingleChainTokenBalanceService(wallet: account, server: server, etherToken: Token(contract: AlphaWallet.Address.make(), server: server, value: "0", type: .nativeCryptocurrency))
        return WalletSession(
            account: account,
            server: server,
            config: config,
            tokenBalanceService: tokenBalanceService,
            analyticsCoordinator: analyticsCoordinator
        )
    }
}
