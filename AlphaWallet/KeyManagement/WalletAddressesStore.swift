//
//  WalletStore.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.01.2022.
//

import Foundation
import Combine

protocol WalletAddressesStoreMigration {
    func migrate(to store: WalletAddressesStore) -> WalletAddressesStore
}

protocol WalletAddressesStore: WalletAddressesStoreMigration {
    var watchAddresses: [String] { get set }
    var ethereumAddressesWithPrivateKeys: [String] { get set }
    var ethereumAddressesWithSeed: [String] { get set }
    var ethereumAddressesProtectedByUserPresence: [String] { get set }
    var hasWallets: Bool { get }
    var wallets: [Wallet] { get }
    var hasMigratedFromKeystoreFiles: Bool { get }
    var walletsPublisher: AnyPublisher<Set<Wallet>, Never> { get }

    mutating func removeAddress(_ account: AlphaWallet.Address)
}

extension WalletAddressesStore {

    mutating func removeAddress(_ account: AlphaWallet.Address) {
        ethereumAddressesWithPrivateKeys = ethereumAddressesWithPrivateKeys.filter { $0 != account.eip55String }
        ethereumAddressesWithSeed = ethereumAddressesWithSeed.filter { $0 != account.eip55String }
        ethereumAddressesProtectedByUserPresence = ethereumAddressesProtectedByUserPresence.filter { $0 != account.eip55String }
        watchAddresses = watchAddresses.filter { $0 != account.eip55String }
    }

    func migrate(to store: WalletAddressesStore) -> WalletAddressesStore {
        var store = store
        store.watchAddresses = watchAddresses
        store.ethereumAddressesWithPrivateKeys = ethereumAddressesWithPrivateKeys
        store.ethereumAddressesWithSeed = ethereumAddressesWithSeed
        store.ethereumAddressesProtectedByUserPresence = ethereumAddressesProtectedByUserPresence

        return store
    }
}
