//
//  DefaultsWalletAddressesStore.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.01.2022.
//

import Foundation
import Combine

public struct DefaultsWalletAddressesStore: WalletAddressesStore {
    public var walletsPublisher: AnyPublisher<Set<Wallet>, Never> {
        walletsSubject.eraseToAnyPublisher()
    }

    private var walletsSubject: CurrentValueSubject<Set<Wallet>, Never> = .init([])

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

    private var didAddWalletSubject: PassthroughSubject<AlphaWallet.Address, Never> = .init()
    private var didRemoveWalletSubject: PassthroughSubject<Wallet, Never> = .init()

    public var didAddWalletPublisher: AnyPublisher<AlphaWallet.Address, Never> {
        didAddWalletSubject.eraseToAnyPublisher()
    }

    public var didRemoveWalletPublisher: AnyPublisher<Wallet, Never> {
        didRemoveWalletSubject.eraseToAnyPublisher()
    }

    mutating public func addToListOfWatchEthereumAddresses(_ address: AlphaWallet.Address) {
        watchAddresses = [watchAddresses, [address.eip55String]].flatMap { $0 }

        didAddWalletSubject.send(address)
    }

    mutating public func addToListOfEthereumAddressesWithPrivateKeys(_ address: AlphaWallet.Address) {
        let updatedOwnedAddresses = Array(Set(ethereumAddressesWithPrivateKeys + [address.eip55String]))
        ethereumAddressesWithPrivateKeys = updatedOwnedAddresses

        didAddWalletSubject.send(address)
    }

    mutating public func addToListOfEthereumAddressesWithSeed(_ address: AlphaWallet.Address) {
        let updated = Array(Set(ethereumAddressesWithSeed + [address.eip55String]))
        ethereumAddressesWithSeed = updated

        didAddWalletSubject.send(address)
    }

    mutating public func addToListOfEthereumAddressesProtectedByUserPresence(_ address: AlphaWallet.Address) {
        let updated = Array(Set(ethereumAddressesProtectedByUserPresence + [address.eip55String]))
        ethereumAddressesProtectedByUserPresence = updated

        didAddWalletSubject.send(address)
    }

    mutating public func removeAddress(_ account: Wallet) {
        ethereumAddressesWithPrivateKeys = ethereumAddressesWithPrivateKeys.filter { $0 != account.address.eip55String }
        ethereumAddressesWithSeed = ethereumAddressesWithSeed.filter { $0 != account.address.eip55String }
        ethereumAddressesProtectedByUserPresence = ethereumAddressesProtectedByUserPresence.filter { $0 != account.address.eip55String }
        watchAddresses = watchAddresses.filter { $0 != account.address.eip55String }

        didRemoveWalletSubject.send(account)
    }
}
