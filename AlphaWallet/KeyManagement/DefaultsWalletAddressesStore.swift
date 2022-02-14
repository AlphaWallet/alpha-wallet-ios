//
//  DefaultsWalletAddressesStore.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.01.2022.
//

import Foundation

struct DefaultsWalletAddressesStore: WalletAddressesStoreType {

    private struct Keys {
        static let watchAddresses = "watchAddresses"
        static let ethereumAddressesWithPrivateKeys = "ethereumAddressesWithPrivateKeys"
        static let ethereumAddressesWithSeed = "ethereumAddressesWithSeed"
        static let ethereumAddressesProtectedByUserPresence = "ethereumAddressesProtectedByUserPresence"
    }
    let userDefaults: UserDefaults
    var hasWallets: Bool {
        return !wallets.isEmpty
    }

    var hasMigratedFromKeystoreFiles: Bool {
        return userDefaults.data(forKey: Keys.ethereumAddressesWithPrivateKeys) != nil
    }

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    var wallets: [Wallet] {
        let watchAddresses = self.watchAddresses.compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(type: .watch($0)) }
        let addressesWithPrivateKeys = ethereumAddressesWithPrivateKeys.compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(type: .real($0)) }
        let addressesWithSeed = ethereumAddressesWithSeed.compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(type: .real($0)) }
        return addressesWithSeed + addressesWithPrivateKeys + watchAddresses
    }

    var watchAddresses: [String] {
        get {
            guard let data = userDefaults.data(forKey: Keys.watchAddresses) else {
                return []
            }
            return NSKeyedUnarchiver.unarchiveObject(with: data) as? [String] ?? []
        }
        set {
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            userDefaults.set(data, forKey: Keys.watchAddresses)
        }
    }

    var ethereumAddressesWithPrivateKeys: [String] {
        get {
            guard let data = userDefaults.data(forKey: Keys.ethereumAddressesWithPrivateKeys) else {
                return []
            }
            return NSKeyedUnarchiver.unarchiveObject(with: data) as? [String] ?? []
        }
        set {
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            userDefaults.set(data, forKey: Keys.ethereumAddressesWithPrivateKeys)
        }
    }

    var ethereumAddressesWithSeed: [String] {
        get {
            guard let data = userDefaults.data(forKey: Keys.ethereumAddressesWithSeed) else {
                return []
            }
            return NSKeyedUnarchiver.unarchiveObject(with: data) as? [String] ?? []
        }
        set {
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            userDefaults.set(data, forKey: Keys.ethereumAddressesWithSeed)
        }
    }

    var ethereumAddressesProtectedByUserPresence: [String] {
        get {
            guard let data = userDefaults.data(forKey: Keys.ethereumAddressesProtectedByUserPresence) else {
                return []
            }

            return NSKeyedUnarchiver.unarchiveObject(with: data) as? [String] ?? []
        }
        set {
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            userDefaults.set(data, forKey: Keys.ethereumAddressesProtectedByUserPresence)
        }
    }
}
