//
//  JsonWalletAddressesStore.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.01.2022.
//

import Foundation

struct JsonWalletAddressesStore: WalletAddressesStoreType {
    private static let walletsFolderForTests = "testSuiteWalletsForWalletAddresses"
    static func createStorage() -> StorageType {
        let directoryUrl: URL = {
            if isRunningTests() {
                let cacheDirectoryUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                let directory = try! FileManager.default.createSubDirectoryIfNotExists(name: walletsFolderForTests, directory: cacheDirectoryUrl)
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

        //NOTE: we want to clear all elready created wallets in cache directory while performing tests
        FileManager.default.removeAllItems(directory: directory)
    }

    private struct Keys {
        static let walletAddresses = "walletAddresses"
    }

    private var storage: StorageType
    private var walletAddresses: WalletAddresses

    init(storage: StorageType = JsonWalletAddressesStore.createStorage()) {
        self.storage = storage

        if let value: WalletAddresses = storage.load(forKey: Keys.walletAddresses) {
            walletAddresses = value
        } else {
            walletAddresses = WalletAddresses()
        }
    }

    var hasAnyStoredData: Bool {
        return storage.dataExists(forKey: Keys.walletAddresses)
    }

    var hasWallets: Bool {
        return !wallets.isEmpty
    }

    var hasMigratedFromKeystoreFiles: Bool {
        walletAddresses.ethereumAddressesWithPrivateKeys != nil
    }

    var wallets: [Wallet] {
        let watchAddresses = self.watchAddresses.compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(type: .watch($0)) }
        let addressesWithPrivateKeys = ethereumAddressesWithPrivateKeys.compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(type: .real($0)) }
        let addressesWithSeed = ethereumAddressesWithSeed.compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(type: .real($0)) }
        return addressesWithSeed + addressesWithPrivateKeys + watchAddresses
    }

    var watchAddresses: [String] {
        get {
            walletAddresses.watchAddresses ?? []
        }
        set {
            walletAddresses.watchAddresses = newValue
            saveWalletCollectionToFile()
        }
    }

    var ethereumAddressesWithPrivateKeys: [String] {
        get {
            walletAddresses.ethereumAddressesWithPrivateKeys ?? []
        }
        set {
            walletAddresses.ethereumAddressesWithPrivateKeys = newValue
            saveWalletCollectionToFile()
        }
    }

    var ethereumAddressesWithSeed: [String] {
        get {
            walletAddresses.ethereumAddressesWithSeed ?? []
        }
        set {
            walletAddresses.ethereumAddressesWithSeed = newValue
            saveWalletCollectionToFile()
        }
    }

    var ethereumAddressesProtectedByUserPresence: [String] {
        get {
            walletAddresses.ethereumAddressesProtectedByUserPresence ?? []
        }
        set {
            walletAddresses.ethereumAddressesProtectedByUserPresence = newValue
            saveWalletCollectionToFile()
        }
    }

    private func saveWalletCollectionToFile() {
        guard let data = try? JSONEncoder().encode(walletAddresses) else {
            return
        }
        storage.setData(data, forKey: Keys.walletAddresses)
    }
}

extension EtherKeystore {
    private static let rawJsonWalletStore = JsonWalletAddressesStore.createStorage()
    
    static func migratedWalletAddressesStore(userDefaults: UserDefaults) -> WalletAddressesStoreType {
        if Features.isJsonFileBasedStorageForWalletAddressesEnabled {
            //NOTE: its quite important to remove test wallets right before fetching, otherwise tests will fails, especially Keystore related
            JsonWalletAddressesStore.removeWalletsFolderForTests()

            let jsonWalletAddressesStore = JsonWalletAddressesStore(storage: rawJsonWalletStore)
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
        } else {
            return DefaultsWalletAddressesStore(userDefaults: userDefaults)
        }
    }
}

private struct WalletAddresses: Codable {
    var watchAddresses: [String]?
    var ethereumAddressesWithPrivateKeys: [String]?
    var ethereumAddressesWithSeed: [String]?
    var ethereumAddressesProtectedByUserPresence: [String]?

    init() {
        watchAddresses = []
        ethereumAddressesWithPrivateKeys = []
        ethereumAddressesWithSeed = []
        ethereumAddressesProtectedByUserPresence = []
    }
}
