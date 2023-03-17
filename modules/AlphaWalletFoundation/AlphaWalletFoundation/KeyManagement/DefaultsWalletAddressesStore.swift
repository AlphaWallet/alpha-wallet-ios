//
//  DefaultsWalletAddressesStore.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.01.2022.
//

import Foundation
import Combine

public struct DefaultsWalletAddressesStore: WalletAddressesStore {
    private struct Keys {
        static let watchAddresses = "watchAddresses"
        static let ethereumAddressesWithPrivateKeys = "ethereumAddressesWithPrivateKeys"
        static let ethereumAddressesWithSeed = "ethereumAddressesWithSeed"
        static let ethereumAddressesProtectedByUserPresence = "ethereumAddressesProtectedByUserPresence"
    }
    let userDefaults: UserDefaults
    public var hasWallets: Bool {
        return !wallets.isEmpty
    }

    public var hasMigratedFromKeystoreFiles: Bool {
        return userDefaults.data(forKey: Keys.ethereumAddressesWithPrivateKeys) != nil
    }

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    //This might not work correctly (since it doesn't read or store the wallet) if we switch back to this class (but we shouldn't because we use it for migrating away from the old wallet storage)
    public var recentlyUsedWallet: Wallet?

    public var wallets: [Wallet] {
        let watchAddresses = self.watchAddresses.compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(address: $0, origin: .watch) }
        let addressesWithPrivateKeys = ethereumAddressesWithPrivateKeys.compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(address: $0, origin: .privateKey) }
        let addressesWithSeed = ethereumAddressesWithSeed.compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(address: $0, origin: .hd) }
        return addressesWithSeed + addressesWithPrivateKeys + watchAddresses
    }

    public var watchAddresses: [String] {
        get {
            return userDefaults.data(forKey: Keys.watchAddresses)
                .flatMap { try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData($0) as? [String] }
                .flatMap { $0 } ?? []
        }
        set {
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) else { return }
            userDefaults.set(data, forKey: Keys.watchAddresses)
        }
    }

    public var ethereumAddressesWithPrivateKeys: [String] {
        get {
            return userDefaults.data(forKey: Keys.ethereumAddressesWithPrivateKeys)
                .flatMap { try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData($0) as? [String] }
                .flatMap { $0 } ?? []
        }
        set {
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) else { return }
            userDefaults.set(data, forKey: Keys.ethereumAddressesWithPrivateKeys)
        }
    }

    public var ethereumAddressesWithSeed: [String] {
        get {
            return userDefaults.data(forKey: Keys.ethereumAddressesWithSeed)
                .flatMap { try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData($0) as? [String] }
                .flatMap { $0 } ?? []
        }
        set {
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) else { return }
            userDefaults.set(data, forKey: Keys.ethereumAddressesWithSeed)
        }
    }

    public var ethereumAddressesProtectedByUserPresence: [String] {
        get {
            return userDefaults.data(forKey: Keys.ethereumAddressesProtectedByUserPresence)
                .flatMap { try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData($0) as? [String] }
                .flatMap { $0 } ?? []
        }
        set {
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) else { return }
            userDefaults.set(data, forKey: Keys.ethereumAddressesProtectedByUserPresence)
        }
    }

    mutating public func add(wallet: Wallet) {
        switch wallet.origin {
        case .hd:
            addToListOfEthereumAddressesWithSeed(wallet.address)
        case .privateKey:
            addToListOfEthereumAddressesWithPrivateKeys(wallet.address)
        case .hardware:
            preconditionFailure("Since we only support hardware wallet *after* we stop using this form of persisting wallets, so hardware wallets never get added here")
        case .watch:
            addToListOfWatchEthereumAddresses(wallet.address)
        }
    }

    mutating private func addToListOfWatchEthereumAddresses(_ address: AlphaWallet.Address) {
        watchAddresses = [watchAddresses, [address.eip55String]].flatMap { $0 }
    }

    mutating private func addToListOfEthereumAddressesWithPrivateKeys(_ address: AlphaWallet.Address) {
        let updatedOwnedAddresses = Array(Set(ethereumAddressesWithPrivateKeys + [address.eip55String]))
        ethereumAddressesWithPrivateKeys = updatedOwnedAddresses
    }

    mutating private func addToListOfEthereumAddressesWithSeed(_ address: AlphaWallet.Address) {
        let updated = Array(Set(ethereumAddressesWithSeed + [address.eip55String]))
        ethereumAddressesWithSeed = updated
    }

    mutating public func addToListOfEthereumAddressesProtectedByUserPresence(_ address: AlphaWallet.Address) {
        let updated = Array(Set(ethereumAddressesProtectedByUserPresence + [address.eip55String]))
        ethereumAddressesProtectedByUserPresence = updated
    }

    mutating public func removeAddress(_ account: Wallet) {
        ethereumAddressesWithPrivateKeys = ethereumAddressesWithPrivateKeys.filter { $0 != account.address.eip55String }
        ethereumAddressesWithSeed = ethereumAddressesWithSeed.filter { $0 != account.address.eip55String }
        ethereumAddressesProtectedByUserPresence = ethereumAddressesProtectedByUserPresence.filter { $0 != account.address.eip55String }
        watchAddresses = watchAddresses.filter { $0 != account.address.eip55String }
    }
}
