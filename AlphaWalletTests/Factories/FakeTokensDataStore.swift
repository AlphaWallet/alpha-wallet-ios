// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import AlphaWalletFoundation

class FakeTokensDataStore: MultipleChainsTokensDataStore {
    convenience init(account: Wallet = .make(), servers: [RPCServer] = [.main]) {
        self.init(store: .fake(for: account), servers: servers)
    }
}
