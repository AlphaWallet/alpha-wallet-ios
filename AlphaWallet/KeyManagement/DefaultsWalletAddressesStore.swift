//
//  DefaultsWalletAddressesStore.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.01.2022.
//

import Foundation
import Combine

struct DefaultsWalletAddressesStore: WalletAddressesStore {
    
    var walletsPublisher: AnyPublisher<Set<Wallet>, Never> {
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
            return userDefaults.data(forKey: Keys.watchAddresses)
                .flatMap { try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData($0) as? [String] }
                .flatMap { $0 } ?? []
        }
        set {
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) else { return }
            userDefaults.set(data, forKey: Keys.watchAddresses)
        }
    }

    var ethereumAddressesWithPrivateKeys: [String] {
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

    var ethereumAddressesWithSeed: [String] {
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

    var ethereumAddressesProtectedByUserPresence: [String] {
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
}
