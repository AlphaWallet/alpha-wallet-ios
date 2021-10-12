// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import RealmSwift

class FakeTokensDataStore: TokensDataStore {
    convenience init(account: Wallet = .make(), server: RPCServer = .main) {
        let realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "MyInMemoryRealmTest"))
        self.init(realm: realm, account: account, server: server)
    }
}
