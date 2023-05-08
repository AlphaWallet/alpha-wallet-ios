// Copyright SIX DAY LLC. All rights reserved.

@testable import AlphaWallet
import AlphaWalletFoundation
import Foundation

class FakeTokensDataStore: MultipleChainsTokensDataStore {
    convenience init(account: Wallet = .make(), servers: [RPCServer] = [.main]) {
        self.init(store: .fake(for: account))
        _ = servers.map { addEthToken(forServer: $0) }
    }
}
