// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import RealmSwift

class FakeTokensDataStore: MultipleChainsTokensDataStore {
    convenience init(account: Wallet = .make()) {
        let realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "MyInMemoryRealmTest"))
        self.init(realm: realm, account: account, servers: [.main])
    }
}
