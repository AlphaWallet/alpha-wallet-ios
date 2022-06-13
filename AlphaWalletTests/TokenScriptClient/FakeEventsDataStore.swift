// Copyright © 2020 Stormbird PTE. LTD.

@testable import AlphaWallet
import RealmSwift

class FakeEventsDataStore: NonActivityMultiChainEventsDataStore {
    convenience init(account: Wallet = .make()) {
        let store = FakeRealmLocalStore()
        self.init(store: store.getOrCreateStore(forWallet: account))
    }
}