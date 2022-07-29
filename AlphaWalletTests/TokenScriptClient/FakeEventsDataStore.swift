// Copyright © 2020 Stormbird PTE. LTD.

@testable import AlphaWallet

class FakeEventsDataStore: NonActivityMultiChainEventsDataStore {
    convenience init(account: Wallet = .make()) {
        let store = FakeRealmLocalStore()
        self.init(store: store.getOrCreateStore(forWallet: account))
    }
}
