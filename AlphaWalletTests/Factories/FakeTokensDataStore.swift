// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import RealmSwift

class FakeTokensDataStore: MultipleChainsTokensDataStore {
    convenience init(account: Wallet = .make(), servers: [RPCServer] = [.main]) {
        let realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "MyInMemoryRealmTest-\(account.address.eip55String)"))
        self.init(realm: realm, servers: servers)
    }
}
