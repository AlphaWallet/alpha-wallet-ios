// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import RealmSwift
import AlphaWalletLogger

public class DatabaseMigration: Initializer {
    let account: Wallet

    lazy var config: Realm.Configuration = RealmConfiguration.configuration(for: account.address)

    public init(account: Wallet) {
        self.account = account
    }

    // swiftlint:disable function_body_length
    public func perform() {
        config.schemaVersion = 13
        config.objectTypes = [
            DelegateContract.self,
            DeletedContract.self,
            EventActivity.self,
            EventInstance.self,
            HiddenContract.self,
            LocalizedOperationObject.self,
            TokenBalance.self,
            TokenInfoObject.self,
            TokenObject.self,
            TransactionObject.self,
            //It is necessary to include these 2 classes even though they are no longer managed in this Realm database (since 8814bd234dec8fc01be2cf9e7201724572627c97 and earlier) because they can still be accessed by users for database migration
            Bookmark.self,
            History.self,
            EnjinTokenObject.self,
            GasPriceObject.self
        ]
        //NOTE: use [weak self] to avoid memory leak
        config.migrationBlock = { [weak self] migration, oldSchemaVersion in
            guard let strongSelf = self else { return }

            if oldSchemaVersion < 2 {
                //Fix bug created during multi-chain implementation. Where TokenObject instances are created from transfer Transaction instances, with the primaryKey as a empty string; so instead of updating an existing TokenObject, a duplicate TokenObject instead was created but with primaryKey empty
                migration.enumerateObjects(ofType: TokenObject.className()) { oldObject, newObject in
                    guard oldObject != nil else { return }
                    guard let newObject = newObject else { return }
                    if let primaryKey = newObject["primaryKey"] as? String, primaryKey.isEmpty {
                        migration.delete(newObject)
                        return
                    }
                }
            }
            if oldSchemaVersion < 3 {
                migration.enumerateObjects(ofType: "Transaction") { oldObject, newObject in
                    guard oldObject != nil else { return }
                    guard let newObject = newObject else { return }
                    newObject["isERC20Interaction"] = false
                }
            }
            if oldSchemaVersion < 4 {
                migration.enumerateObjects(ofType: TokenObject.className()) { oldObject, newObject in
                    guard let oldObject = oldObject else { return }
                    guard let newObject = newObject else { return }
                    //Fix bug introduced when OpenSea suddenly includes the DAI stablecoin token in their results with an existing versioned API endpoint, and we wrongly tagged it as ERC721, possibly crashing when we fetch the balance (casting a very large ERC20 balance with 18 decimals to an Int)
                    guard let contract = oldObject["contract"] as? String, contract == "0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359" else { return }
                    newObject["rawType"] = "ERC20"
                }
            }
            if oldSchemaVersion < 5 {
                migration.enumerateObjects(ofType: TokenObject.className()) { oldObject, newObject in
                    guard let oldObject = oldObject else { return }
                    guard let newObject = newObject else { return }
                    //Fix bug introduced when OpenSea suddenly includes the DAI stablecoin token in their results with an existing versioned API endpoint, and we wrongly tagged it as ERC721 with decimals=0. The earlier migration (version=4) only set the type back to ERC20, but the decimals remained as 0
                    guard let contract = oldObject["contract"] as? String, contract == "0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359" else { return }
                    newObject["decimals"] = 18
                }
            }
            if oldSchemaVersion < 6 {
                migration.enumerateObjects(ofType: TokenObject.className()) { oldObject, newObject in
                    guard oldObject != nil else { return }
                    guard let newObject = newObject else { return }

                    newObject["shouldDisplay"] = true
                    newObject["sortIndex"] = RealmProperty<Int?>()
                }
            }
            if oldSchemaVersion < 7 {
                //Fix bug where we marked all transactions as completed successfully without checking `isError` from Etherscan
                migration.deleteData(forType: "Transaction")
                for each in RPCServer.availableServers {
                    Config.setLastFetchedErc20InteractionBlockNumber(0, server: each, wallet: strongSelf.account.address)
                }
                migration.deleteData(forType: EventActivity.className())
            }
            if oldSchemaVersion < 8 {
                //Clear all transactions data so we can fetch them again and capture `LocalizedOperationObject` children correctly
                migration.deleteData(forType: "Transaction")
                migration.deleteData(forType: LocalizedOperationObject.className())
                for each in RPCServer.availableServers {
                    Config.setLastFetchedErc20InteractionBlockNumber(0, server: each, wallet: strongSelf.account.address)
                }
                migration.deleteData(forType: EventActivity.className())
            }

            if oldSchemaVersion < 9 {
                //no-op
            }

            if oldSchemaVersion < 10 {
                //no-op
            }

            if oldSchemaVersion < 11 {
                migration.deleteData(forType: TokenInfoObject.className())
                migration.enumerateObjects(ofType: TokenObject.className()) { old, new in
                    guard let uid = old?["primaryKey"] as? String else { return }
                    let info = migration.create(TokenInfoObject.className(), value: [
                        "uid": uid
                    ])
                    new?["_info"] = info
                }
            }

            if oldSchemaVersion < 12 {
                migration.deleteData(forType: TokenBalance.className())
            }

            if oldSchemaVersion < 13 {
                migration.deleteData(forType: "Transaction")
            }

        }
    }
    // swiftlint:enable function_body_length
}

import AlphaWalletCore

extension DatabaseMigration {
    //e.g https://stackoverflow.com/questions/45683173/realm-crash-when-invalidating-while-updating
    private static let walletsToDeleted = Storage<[AlphaWallet.Address]>(fileName: "deleted_wallets", defaultValue: [])

    public static func addToDeleteList(address: AlphaWallet.Address) {
        walletsToDeleted.value = Array(Set(walletsToDeleted.value + [address]))
    }

    public static func dropDeletedRealmFiles(excluding wallets: [Wallet]) {
        let walletsToDelete = walletsToDeleted.value.filter { address in !wallets.contains(where: { address == $0.address }) }
        for address in walletsToDelete {
            let config = RealmConfiguration.configuration(for: address)

            for each in realmFilesUrls(config: config) {
                try? FileManager.default.removeItem(at: each)
            }
        }

        walletsToDeleted.value = []
    }

    public static func realmFilesUrls(account: Wallet) -> [URL] {
        let config = RealmConfiguration.configuration(for: account.address)
        return realmFilesUrls(config: config)
    }

    public static func realmFilesUrls(config: Realm.Configuration) -> [URL] {
        guard let realmUrl = config.fileURL else { return [] }

        let realmUrls = [
            realmUrl,
            realmUrl.appendingPathExtension("lock"),
            realmUrl.appendingPathExtension("note"),
            realmUrl.appendingPathExtension("management")
        ]

        return realmUrls
    }

    //We use the existence of realm databases as a heuristic to determine if there are wallets (including watched ones)
    public static var hasRealmDatabasesForWallet: Bool {
        let directory = RealmConfiguration.defaultRealmFolderUrl
        if let contents = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))?.filter({ $0.lastPathComponent.starts(with: "0") }) {
            return !contents.isEmpty
        } else {
            //No reason why it should come here
            return false
        }
    }

    //NOTE: This function is using to make sure that wallets in user defaults will be removed after restoring backup from iCloud. Realm files don't backup to iCloud but user defaults does backed up.
    public static func removeWalletsIfRealmFilesMissed(keystore: Keystore) {
        for wallet in keystore.wallets {
            let config = RealmConfiguration.configuration(for: wallet.address)

            guard let path = config.fileURL else { continue }

            //NOTE: make sure realm files exists, if not then delete this wallets from user defaults.
            if FileManager.default.fileExists(atPath: path.path) {
                //no op
            } else {
                _ = keystore.delete(wallet: wallet)
            }
        }
    }

    public static func oneTimeMigrationForBookmarksAndUrlHistoryToSharedRealm(keystore: Keystore, config: Config) {
        guard !config.hasMigratedToSharedRealm() else { return }

        for each in keystore.wallets {
            let migration = DatabaseMigration(account: each)
            migration.perform()
            migration.oneTimeMigrationForBookmarksAndUrlHistoryToSharedRealm()
        }

        config.markAsMigratedToSharedRealmDatabase()
    }

    private func oneTimeMigrationForBookmarksAndUrlHistoryToSharedRealm() {
        let oldPerWalletDatabase = try! Realm(configuration: config)
        let realm = Realm.shared()

        try? realm.write {
            for each in oldPerWalletDatabase.objects(History.self) {
                realm.create(History.self, value: each, update: .all)
            }
            for each in oldPerWalletDatabase.objects(Bookmark.self) {
                realm.create(Bookmark.self, value: each, update: .all)
            }
        }
    }
}

fileprivate extension Config {
    private static var storageKey: String = "migrationsToSharedRealmForBookmarks"

    func hasMigratedToSharedRealm() -> Bool {
        defaults.bool(forKey: Config.storageKey)
    }

    func markAsMigratedToSharedRealmDatabase() {
        defaults.set(true, forKey: Config.storageKey)
    }
}
