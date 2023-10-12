//
//  RealmStore.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 06.04.2022.
//

import Foundation
import Combine
import Realm
import RealmSwift

//TODO these fakeXXX functions should only be in the test target
public func fakeRealmConfiguration(wallet: Wallet) -> Realm.Configuration {
    let uuid = UUID().uuidString
    //We don't use `Realm.Configuration(inMemoryIdentifier:)` because they don't seem to work properly when we have multiple Realm instances accessing the same store. Using file-based Realm for tests runs the slight risk of bloat if we don't clean up properly; but it's acceptable
    return Realm.Configuration(fileURL: URL(fileURLWithPath: try! RealmConfiguration._RLMRealmPathInCacheFolderForFile("\(wallet.address.eip55String)-\(uuid).realm"), isDirectory: false))
}

public func fakeRealmConfiguration() -> Realm.Configuration {
    let uuid = UUID().uuidString
    //We don't use `Realm.Configuration(inMemoryIdentifier:)` because they don't seem to work properly when we have multiple Realm instances accessing the same store. Using file-based Realm for tests runs the slight risk of bloat if we don't clean up properly; but it's acceptable
    return Realm.Configuration(fileURL: URL(fileURLWithPath: try! RealmConfiguration._RLMRealmPathInCacheFolderForFile("\(uuid).realm"), isDirectory: false))
}

open class RealmStore {
    public static func threadName(for wallet: Wallet) -> String {
        return "org.alphawallet.swift.realmStore.\(wallet.address).wallet"
    }
    var cancellables = Set<AnyCancellable>()
    private let config: Realm.Configuration
    private let thread: RunLoopThread = .init()

    public var fileURL: URL? {
        return config.fileURL
    }

    public init(config: Realm.Configuration, name: String = "org.alphawallet.swift.realmStore") {
        self.config = config
        thread.name = name
        thread.start()
    }

    //TODO we'll want this to be really async
    public func perform(_ block: @escaping (Realm) -> Void) async {
        let config = config
        self.thread._perform {
            let realm = try! Realm(configuration: config)
            block(realm)
        }
    }

    public func performSync(_ block: @escaping (Realm) -> Void) async {
        let config = config
        self.thread._perform {
            let realm = try! Realm(configuration: config)
            block(realm)
        }
    }
}

extension RealmStore {
    public static var shared: RealmStore = RealmStore(config: Realm.shared().configuration)

    public class func storage(for wallet: Wallet) -> RealmStore {
        return RealmStore(config: Realm.realm(for: wallet).configuration, name: RealmStore.threadName(for: wallet))
    }
}

extension Realm {
    public static func realm(for account: Wallet) -> Realm {
        let migration = DatabaseMigration(account: account)
        migration.perform()

        return try! Realm(configuration: migration.config)
    }

    public static func shared(_ name: String = "Shared") -> Realm {
        var configuration = RealmConfiguration.configuration(name: name)
        configuration.objectTypes = [
            Bookmark.self,
            History.self,
            EnsRecordObject.self,
            ContractAddressObject.self,
            TickerIdObject.self,
            KnownTickerIdObject.self,
            CoinTickerObject.self,
            AssignedCoinTickerIdObject.self
        ]

        configuration.schemaVersion = 2
        configuration.migrationBlock = { migration, oldSchemaVersion in
            if oldSchemaVersion < 1 {
                migration.enumerateObjects(ofType: CoinTickerObject.className()) { _, newObject in
                    newObject?["currency"] = Currency.USD.code
                }
            }

            if oldSchemaVersion < 2 {
                migration.deleteData(forType: EventActivity.className())
                migration.deleteData(forType: CoinTickerObject.className())
                migration.deleteData(forType: AssignedCoinTickerIdObject.className())
            }
        }

        let realm = try! Realm(configuration: configuration)

        return realm
    }

    public func safeWrite(_ block: (() throws -> Void)) throws {
        if isInWriteTransaction {
            try block()
        } else {
            try write(block)
        }
    }
}
