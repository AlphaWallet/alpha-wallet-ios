// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import RealmSwift

class FakeTransactionsStorage: TransactionDataStore {
    convenience init(server: RPCServer = .main, wallet: Wallet = .init(type: .watch(Constants.nativeCryptoAddressInDatabase))) {
        let realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "MyInMemoryRealm-\(server)-\(wallet.address.eip55String)"))
        self.init(realm: realm)
    }
}
