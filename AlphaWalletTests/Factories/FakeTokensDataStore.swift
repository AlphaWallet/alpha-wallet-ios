// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet

class FakeTokensDataStore: MultipleChainsTokensDataStore {
    convenience init(account: Wallet = .make(), servers: [RPCServer] = [.main]) {
        let store = FakeRealmLocalStore()
        self.init(store: store.getOrCreateStore(forWallet: account), servers: servers)
    }
}
