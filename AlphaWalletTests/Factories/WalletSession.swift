// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet

extension WalletSession {
    static func make(
        account: Wallet = .make(),
        server: RPCServer = .main,
        config: Config = .make(),
        tokenBalanceService: TokenBalanceService
    ) -> WalletSession {
        return WalletSession(
            account: account,
            server: server,
            config: config,
            tokenBalanceService: tokenBalanceService
        )
    }

    static func make(
        account: Wallet = .make(),
        server: RPCServer = .main,
        config: Config = .make()
    ) -> WalletSession {
        let tokenBalanceService = FakeSingleChainTokenBalanceService(wallet: account, server: server, etherToken: TokenObject(contract: AlphaWallet.Address.make(), server: server, value: "0", type: .nativeCryptocurrency))
        return WalletSession(
            account: account,
            server: server,
            config: config,
            tokenBalanceService: tokenBalanceService
        )
    }

    static func makeStormBirdSession(
        account: Wallet = .makeStormBird(),
        server: RPCServer,
        config: Config = .make(),
        tokenBalanceService: TokenBalanceService
    ) -> WalletSession {
        let tokenBalanceService = FakeSingleChainTokenBalanceService(wallet: account, server: server, etherToken: TokenObject(contract: AlphaWallet.Address.make(), server: server, value: "0", type: .nativeCryptocurrency))
        return WalletSession(
            account: account,
            server: server,
            config: config,
            tokenBalanceService: tokenBalanceService
        )
    }
}
