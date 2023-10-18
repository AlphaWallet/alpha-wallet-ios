//
//  JsonWalletAddressesStore.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.01.2022.
//

import Foundation
import Combine
import AlphaWalletCore

public struct JsonWalletAddressesStore: WalletAddressesStore {
    private static let walletsFolderForTests = "testSuiteWalletsForWalletAddresses"
    public static func createStorage() -> StorageType {
        let directoryUrl: URL = {
            if isRunningTests() {
                let uuid = UUID().uuidString
                let cacheDirectoryUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                let directory = try! FileManager.default.createSubDirectoryIfNotExists(name: "\(walletsFolderForTests)/\(uuid)", directory: cacheDirectoryUrl)
                return directory
            } else {
                let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                return paths[0]
            }
        }()

        return FileStorage(fileExtension: "json", directoryUrl: directoryUrl)
    }

    static func removeWalletsFolderForTests() {
        guard isRunningTests() else { return }

        let cacheDirectoryUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = cacheDirectoryUrl.appendingPathComponent(walletsFolderForTests)

        //NOTE: we want to clear all already created wallets in cache directory while performing tests
        FileManager.default.removeAllItems(directory: directory)
    }

    private struct Keys {
        static let walletAddresses = "walletAddresses"
    }

    private var storage: StorageType
    private var walletAddresses: WalletAddresses

    public var recentlyUsedWallet: Wallet? {
        get {
            guard let address = walletAddresses.recentlyUsedWallet else { return nil }
            return wallets.filter { $0.address.sameContract(as: address) }.first
        }
        set {
            let value = newValue?.address.eip55String
            guard walletAddresses.recentlyUsedWallet != value else { return }
            walletAddresses.recentlyUsedWallet = value

            saveWalletCollectionToFile()
        }
    }

    var hasAnyStoredData: Bool {
        return storage.dataExists(forKey: Keys.walletAddresses)
    }

    public var hasWallets: Bool {
        return !wallets.isEmpty
    }

    public var hasMigratedFromKeystoreFiles: Bool {
        walletAddresses.ethereumAddressesWithPrivateKeys != nil
    }

    public var wallets: [Wallet] {
        return Array(walletAddresses.wallets)
    }

    public var watchAddresses: [String] {
        get {
            walletAddresses.watchAddresses ?? []
        }
        set {
            guard walletAddresses.watchAddresses != newValue else { return }
            walletAddresses.watchAddresses = newValue
            saveWalletCollectionToFile()
        }
    }

    //TODO have proper storage. Maybe a dictionary since we want to support more than 1 type of hardware wallet
    public var ethereumAddressesWithHardwareWallet: [String] {
        get {
            walletAddresses.ethereumAddressesWithHardwareWallet ?? []
        }
        set {
            guard walletAddresses.ethereumAddressesWithHardwareWallet != newValue else { return }
            walletAddresses.ethereumAddressesWithHardwareWallet = newValue
            saveWalletCollectionToFile()
        }
    }

    public var ethereumAddressesWithPrivateKeys: [String] {
        get {
            walletAddresses.ethereumAddressesWithPrivateKeys ?? []
        }
        set {
            guard walletAddresses.ethereumAddressesWithPrivateKeys != newValue else { return }
            walletAddresses.ethereumAddressesWithPrivateKeys = newValue
            saveWalletCollectionToFile()
        }
    }

    public var ethereumAddressesWithSeed: [String] {
        get {
            walletAddresses.ethereumAddressesWithSeed ?? []
        }
        set {
            guard walletAddresses.ethereumAddressesWithSeed != newValue else { return }
            walletAddresses.ethereumAddressesWithSeed = newValue
            saveWalletCollectionToFile()
        }
    }

    public var ethereumAddressesProtectedByUserPresence: [String] {
        get {
            walletAddresses.ethereumAddressesProtectedByUserPresence ?? []
        }
        set {
            guard walletAddresses.ethereumAddressesProtectedByUserPresence != newValue else { return }
            walletAddresses.ethereumAddressesProtectedByUserPresence = newValue
            saveWalletCollectionToFile()
        }
    }

    public init(storage: StorageType = JsonWalletAddressesStore.createStorage()) {
        self.storage = storage

        if let value: WalletAddresses = storage.load(forKey: Keys.walletAddresses) {
            walletAddresses = value
        } else {
            walletAddresses = WalletAddresses()
        }
    }

    mutating private func saveWalletCollectionToFile() {
        guard let data = try? JSONEncoder().encode(walletAddresses) else { return }
        storage.setData(data, forKey: Keys.walletAddresses)
    }

    mutating public func add(wallet: Wallet) {
        switch wallet.origin {
        case .hd:
            addToListOfEthereumAddressesWithSeed(wallet.address)
        case .privateKey:
            addToListOfEthereumAddressesWithPrivateKeys(wallet.address)
        case .watch:
            addToListOfWatchEthereumAddresses(wallet.address)
        case .hardware:
            addToListOfEthereumAddressesWithHardwareWallet(wallet.address)
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

    mutating private func addToListOfEthereumAddressesWithHardwareWallet(_ address: AlphaWallet.Address) {
        ethereumAddressesWithHardwareWallet = [ethereumAddressesWithHardwareWallet, [address.eip55String]].flatMap { $0 }
    }

    mutating public func removeAddress(_ account: Wallet) {
        ethereumAddressesWithPrivateKeys = ethereumAddressesWithPrivateKeys.filter { $0 != account.address.eip55String }
        ethereumAddressesWithSeed = ethereumAddressesWithSeed.filter { $0 != account.address.eip55String }
        ethereumAddressesProtectedByUserPresence = ethereumAddressesProtectedByUserPresence.filter { $0 != account.address.eip55String }
        ethereumAddressesWithHardwareWallet = ethereumAddressesWithHardwareWallet.filter { $0 != account.address.eip55String }
        watchAddresses = watchAddresses.filter { $0 != account.address.eip55String }
    }

}

extension EtherKeystore {
    public static func migratedWalletAddressesStore(userDefaults: UserDefaults) -> WalletAddressesStore {
        //NOTE: its quite important to remove test wallets right before fetching, otherwise tests will fails, especially Keystore related
        JsonWalletAddressesStore.removeWalletsFolderForTests()

        let jsonWalletAddressesStore = JsonWalletAddressesStore(storage: JsonWalletAddressesStore.createStorage())
        if !jsonWalletAddressesStore.hasAnyStoredData {

            let userDefaultsWalletAddressesStore = DefaultsWalletAddressesStore(userDefaults: userDefaults)
            if jsonWalletAddressesStore.hasWallets && !userDefaultsWalletAddressesStore.hasWallets {
                return jsonWalletAddressesStore
            } else {
                return userDefaultsWalletAddressesStore.migrate(to: jsonWalletAddressesStore)
            }
        } else {
            return jsonWalletAddressesStore
        }
    }
}

private struct WalletAddresses: Codable {
    var watchAddresses: [String]?
    var ethereumAddressesWithPrivateKeys: [String]?
    var ethereumAddressesWithSeed: [String]?
    var ethereumAddressesProtectedByUserPresence: [String]?
    var ethereumAddressesWithHardwareWallet: [String]?
    var recentlyUsedWallet: String?

    init() {
        watchAddresses = []
        ethereumAddressesWithPrivateKeys = []
        ethereumAddressesWithSeed = []
        ethereumAddressesProtectedByUserPresence = []
        ethereumAddressesWithHardwareWallet = []
        recentlyUsedWallet = nil
    }

    var wallets: Set<Wallet> {
        let watchAddresses = (watchAddresses ?? []).compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(address: $0, origin: .watch) }
        let addressesWithPrivateKeys = (ethereumAddressesWithPrivateKeys ?? []).compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(address: $0, origin: .privateKey) }
        let addressesWithSeed = (ethereumAddressesWithSeed ?? []).compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(address: $0, origin: .hd) }
        let ethereumAddressesWithHardwareWallet = (ethereumAddressesWithHardwareWallet ?? []).compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(address: $0, origin: .hardware) }

        return Set(addressesWithSeed + addressesWithPrivateKeys + watchAddresses + ethereumAddressesWithHardwareWallet)
    }
}
