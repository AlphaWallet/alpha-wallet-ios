// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import RealmSwift

class FakeTokensDataStore: TokensDataStore {
    convenience init() {
        let realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "MyInMemoryRealmTest"))
        let account: Wallet = .make()
        let config: Config = .make()
        self.init(realm: realm, account: account, server: .main, config: config, assetDefinitionStore: AssetDefinitionStore())
    }
}
