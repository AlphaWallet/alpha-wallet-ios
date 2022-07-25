//
//  FakeRealmLocalStore.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

@testable import AlphaWallet
import Foundation
import RealmSwift

fileprivate extension Realm {
    static func fake(for wallet: Wallet) -> Realm {
        let uuid = UUID().uuidString
        return try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "MyInMemoryRealm-\(wallet.address.eip55String)-\(uuid)"))
    }
}

class FakeRealmLocalStore: LocalStore {
    func getOrCreateStore(forWallet wallet: Wallet) -> RealmStore {
        return RealmStore(realm: Realm.fake(for: wallet), name: RealmStore.threadName(for: wallet))
    }

    func removeStore(forWallet wallet: Wallet) {
        //no-op
    }
}
