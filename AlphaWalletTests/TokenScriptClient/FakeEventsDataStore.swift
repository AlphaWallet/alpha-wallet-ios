// Copyright © 2020 Stormbird PTE. LTD.

@testable import AlphaWallet
import RealmSwift

class FakeEventsDataStore: NonActivityMultiChainEventsDataStore {
    convenience init(account: Wallet = .make()) {
        let realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "MyInMemoryRealmTest-\(account.address.eip55String)"))
        self.init(realm: realm)
    }
}
