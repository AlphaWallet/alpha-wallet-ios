//
//  RealmLocalStore.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Foundation
import RealmSwift

protocol LocalStore {
    func getOrCreateStore(forWallet wallet: Wallet) -> RealmStore
    func removeStore(forWallet wallet: Wallet)
}

final class RealmLocalStore: LocalStore {
    private var cachedStores: ThreadSafeDictionary<Wallet, RealmStore> = .init()

    func getOrCreateStore(forWallet wallet: Wallet) -> RealmStore {
        if let store = cachedStores[wallet] {
            return store
        } else {
            let realm: Realm = Wallet.functional.realm(forAccount: wallet)
            let store = RealmStore(realm: realm)
            cachedStores[wallet] = store

            return store
        }
    }

    func removeStore(forWallet wallet: Wallet) {
        cachedStores.removeValue(forKey: wallet)
    }
}
