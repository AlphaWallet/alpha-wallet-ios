//
//  RealmStore.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 06.04.2022.
//

import Realm
import RealmSwift
import Foundation

final class RealmStore {
    private let syncQueue: DispatchQueue
    private let config: Realm.Configuration
    private let mainThreadRealm: Realm

    public init(syncQueue: DispatchQueue = DispatchQueue(label: "com.RealmStore.syncQueue", qos: .background), realm: Realm) {
        self.syncQueue = syncQueue
        self.mainThreadRealm = realm
        self.config = realm.configuration
    }

    func performSync(_ callback: (Realm) -> Void) {
        if Thread.isMainThread {
            callback(mainThreadRealm)
        } else {
            dispatchPrecondition(condition: .notOnQueue(syncQueue))
            syncQueue.sync {
                autoreleasepool {
                    guard let realm = try? Realm(configuration: config) else { return }
                    callback(realm)
                }
            }
        }
    }
}

extension Realm {

    static func realm(forAccount account: Wallet) -> Realm {
        let migration = DatabaseMigration(account: account)
        migration.perform()

        let realm = try! Realm(configuration: migration.config)

        return realm
    }

    static func shared(_ name: String = "Shared") -> Realm {
        let configuration = RealmConfiguration.configuration(name: name)
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
