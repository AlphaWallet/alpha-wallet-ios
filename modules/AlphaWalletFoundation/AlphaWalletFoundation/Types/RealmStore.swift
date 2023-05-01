//
//  RealmStore.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 06.04.2022.
//

import Realm
import RealmSwift
import Foundation

public func fakeRealm(wallet: Wallet, inMemoryIdentifier: String = "MyInMemoryRealm") -> Realm {
    let uuid = UUID().uuidString
    return try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "\(inMemoryIdentifier)-\(wallet.address.eip55String)-\(uuid)"))
}

public func fakeRealm(inMemoryIdentifier: String = "MyInMemoryRealm") -> Realm {
    let uuid = UUID().uuidString
    return try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "\(inMemoryIdentifier)-\(uuid)"))
}

open class RealmStore {
    public static func threadName(for wallet: Wallet) -> String {
        return "org.alphawallet.swift.realmStore.\(wallet.address).wallet"
    }
    private let config: Realm.Configuration
    private let thread: RunLoopThread = .init()
    private let mainThreadRealm: Realm
    //NOTE: Making it as lazy removes blocking main thread (when init method get called), and we sure that backgroundThreadRealm always get called in thread.performSync() { context
    private lazy var backgroundThreadRealm: Realm = {
        guard let realm = try? Realm(configuration: config) else { fatalError("Failure to resolve background realm") }

        return realm
    }()
    fileprivate let queueForRealmStore = DispatchQueue(label: "org.alphawallet.swift.realm.store", qos: .background)

    public init(realm: Realm, name: String = "org.alphawallet.swift.realmStore") {
        self.mainThreadRealm = realm
        config = realm.configuration

        thread.name = name
        thread.start()
    }

    public func performSync(_ block: @escaping (Realm) -> Void) {
        if Thread.isMainThread {
            block(mainThreadRealm)
        } else {
            //NOTE: synchronize calls from different threads to avoid
            //*** -[AlphaWallet.RunLoopThread performSelector:onThread:withObject:waitUntilDone:modes:]: target thread exited while waiting for the perform
            dispatchPrecondition(condition: .notOnQueue(queueForRealmStore))
            queueForRealmStore.sync {
                //NOTE: perform an operation on run loop thread
                thread._perform {
                    block(self.backgroundThreadRealm)
                }
            }
        }
    }
}

extension RealmStore {
    public static var shared: RealmStore = RealmStore(realm: Realm.shared())

    public class func storage(for wallet: Wallet) -> RealmStore {
        return RealmStore(realm: .realm(for: wallet), name: RealmStore.threadName(for: wallet))
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
