// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet

extension WalletSession {
    static func make(
        account: Wallet = .make(),
        server: RPCServer = .main,
        config: Config = .make()
    ) -> WalletSession {
        return WalletSession(
            account: account,
            server: server,
            config: config,
            tokensDataStore: FakeTokensDataStore()
        )
    }

    static func makeStormBirdSession(
        account: Wallet = .makeStormBird(),
        server: RPCServer,
        config: Config = .make()
    ) -> WalletSession {
        return WalletSession(
            account: account,
            server: server,
            config: config,
            tokensDataStore: FakeTokensDataStore()
        )
    }
}
