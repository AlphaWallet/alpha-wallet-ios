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
    private var cachedStores: AtomicDictionary<Wallet, RealmStore> = .init()

    func getOrCreateStore(forWallet wallet: Wallet) -> RealmStore {
        if let store = cachedStores[wallet] {
            return store
        } else {
            let store = RealmStore(realm: .realm(for: wallet), name: RealmStore.threadName(for: wallet))
            cachedStores[wallet] = store

            return store
        }
    }

    func removeStore(forWallet wallet: Wallet) {
        cachedStores.removeValue(forKey: wallet)
    }
}
