//
//  FakeRealmLocalStore.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

@testable import AlphaWallet
import RealmSwift

fileprivate extension Realm {
    static func fake(for wallet: Wallet) -> Realm {
        return try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "MyInMemoryRealm-\(wallet.address.eip55String)"))
    }
}

class FakeRealmLocalStore: LocalStore {
    private var cachedStores: AtomicDictionary<Wallet, RealmStore> = .init()

    func getOrCreateStore(forWallet wallet: Wallet) -> RealmStore {
        if let store = cachedStores[wallet] {
            return store
        } else {
            let store = RealmStore(realm: Realm.fake(for: wallet), name: RealmStore.threadName(for: wallet))
            cachedStores[wallet] = store

            return store
        }
    }

    func removeStore(forWallet wallet: Wallet) {
        cachedStores.removeValue(forKey: wallet)
    }
}
