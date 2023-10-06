// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import RealmSwift

public struct RealmConfiguration {
    private static let walletsFolderForTests = "testSuiteWalletsForRealm"

    public static func configuration(for address: AlphaWallet.Address) -> Realm.Configuration {
        var config = realmConfiguration()
        config.fileURL = defaultRealmFolderUrl.appendingPathComponent("\(address.eip55String.lowercased()).realm")
        addProtectionKeyNone(for: config)

        return config
    }

    public static func configuration(for account: Wallet, server: RPCServer) -> Realm.Configuration {
        var config = realmConfiguration()
        config.fileURL = defaultRealmFolderUrl.appendingPathComponent("\(account.address.eip55String.lowercased())-\(server.chainID).realm")
        addProtectionKeyNone(for: config)

        return config
    }

    public static func configuration(name: String) -> Realm.Configuration {
        var config = realmConfiguration()
        config.fileURL = defaultRealmFolderUrl.appendingPathComponent("\(name).realm")
        addProtectionKeyNone(for: config)

        return config
    }

    private static func addProtectionKeyNone(for config: Realm.Configuration) {
        for var each in DatabaseMigration.realmFilesUrls(config: config) {
            try? each.addProtectionKeyNone()
        }
    }

    public static var defaultRealmFolderUrl: URL {
        return realmConfiguration().fileURL!.deletingLastPathComponent()
    }

    private static func realmConfiguration() -> Realm.Configuration {
        let config: Realm.Configuration
        if isRunningTests() {
            config = Realm.Configuration(fileURL: URL(fileURLWithPath: try! _RLMRealmPathInCacheFolderForFile("default.realm"), isDirectory: false))
        } else {
            config = Realm.Configuration()
        }

        for var each in DatabaseMigration.realmFilesUrls(config: config) {
            try? each.addProtectionKeyNone()
        }
        return config
    }

    public static func _RLMRealmPathInCacheFolderForFile(_ fileName: String) throws -> String {
        let fileManager = FileManager.default

        func createSubDirectoryIfNotExists(name: String) throws -> URL {
            let documentsURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]

            let directory = documentsURL.appendingPathComponent(name)
            guard !fileManager.fileExists(atPath: directory.absoluteString) else { return directory }
            try fileManager.createDirectory(atPath: directory.path, withIntermediateDirectories: true, attributes: nil)

            return directory
        }

        var directory = try createSubDirectoryIfNotExists(name: walletsFolderForTests)
        directory.appendPathComponent(fileName)

        return directory.path
    }

    static func removeWalletsFolderForTests(name: String = walletsFolderForTests) throws {
        guard isRunningTests() else { return }

        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = documentsURL.appendingPathComponent(name)

        try? fileManager.removeItem(atPath: directory.path)
    }
}

extension FileManager {

    public func removeAllItems(directory: URL) {
        do {
            let urls = try contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for url in urls {
                try removeItem(at: url)
            }
        } catch {
            //no-op
        }
    }

    @discardableResult public func createSubDirectoryIfNotExists(name: String, directory root: URL) throws -> URL {
        let directory = root.appendingPathComponent(name)
        guard !fileExists(atPath: directory.absoluteString) else { return directory }
        try createDirectory(atPath: directory.path, withIntermediateDirectories: true, attributes: nil)

        return directory
    }
}
