//
//  FakeRealmLocalStore.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

@testable import AlphaWallet
import Foundation

class FakeRealmLocalStore: LocalStore {
    func getOrCreateStore(forWallet wallet: Wallet) -> RealmStore {
        return RealmStore(realm: fakeRealm(wallet: wallet), name: RealmStore.threadName(for: wallet))
    }

    func removeStore(forWallet wallet: Wallet) {
        //no-op
    }
}
