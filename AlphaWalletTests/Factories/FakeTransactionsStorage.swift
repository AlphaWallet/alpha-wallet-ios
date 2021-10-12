// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import RealmSwift

class FakeTransactionsStorage: TransactionsStorage {
    convenience init(server: RPCServer = .main) {
        let realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "MyInMemoryRealm"))
        self.init(realm: realm, server: server, delegate: nil)
    }
}
