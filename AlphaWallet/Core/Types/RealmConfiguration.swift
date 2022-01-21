// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import RealmSwift

struct RealmConfiguration {
    private static let walletsFolderForTests = "testSuiteWalletsForRealm"
    static func configuration(for account: Wallet, server: RPCServer) -> Realm.Configuration {
        var config = realmConfiguration()
        config.fileURL = defaultRealmFolderUrl.appendingPathComponent("\(account.address.eip55String.lowercased())-\(server.chainID).realm")
        return config
    }

    static var defaultRealmFolderUrl: URL {
        return realmConfiguration().fileURL!.deletingLastPathComponent()
    }

    private static func realmConfiguration() -> Realm.Configuration {
        if isRunningTests() {
            return Realm.Configuration(fileURL: URL(fileURLWithPath: try! _RLMRealmPathInCacheFolderForFile("default.realm"), isDirectory: false))
        } else {
            return Realm.Configuration()
        }
    }
    
    private static func _RLMRealmPathInCacheFolderForFile(_ fileName: String) throws -> String {
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

        try? fileManager.removeItem(atPath: directory.absoluteString)
    }

    static func configuration(for account: Wallet) -> Realm.Configuration {
        var config = realmConfiguration()
        config.fileURL = defaultRealmFolderUrl.appendingPathComponent("\(account.address.eip55String.lowercased()).realm")
        return config
    }

}

extension FileManager {
    
    func removeAllItems(directory: URL) {
        do {
            let urls = try contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for url in urls {
                try removeItem(at: url)
            }
        } catch {
            //no-op
        }
    }

    @discardableResult func createSubDirectoryIfNotExists(name: String, directory root: URL) throws -> URL {
        let directory = root.appendingPathComponent(name)
        guard !fileExists(atPath: directory.absoluteString) else { return directory }
        try createDirectory(atPath: directory.path, withIntermediateDirectories: true, attributes: nil)

        return directory
    }
}
