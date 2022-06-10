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
    static func threadName(for wallet: Wallet) -> String {
        return "org.alphawallet.swift.realmStore.\(wallet.address).wallet"
    }

    private let thread: RunLoopThread = .init()
    private let mainThreadRealm: Realm
    private var backgroundThreadRealm: Realm?

    public init(realm: Realm, name: String = "org.alphawallet.swift.realmStore") {
        self.mainThreadRealm = realm
        let config = realm.configuration

        thread.name = name
        thread.start()

        thread.performSync() {
            self.backgroundThreadRealm = try? Realm(configuration: config)
        }

        assert(backgroundThreadRealm != nil)
    }

    func performSync(_ callback: @escaping (Realm) -> Void) {
        if Thread.isMainThread {
            callback(mainThreadRealm)
        } else {
            thread.performSync() {
                guard let realm = self.backgroundThreadRealm else { fatalError("Failure to resolve background realm") }
                callback(realm)
            }
        }
    }
}

extension Realm {

    static func realm(for account: Wallet) -> Realm {
        let migration = DatabaseMigration(account: account)
        migration.perform()

        let realm = try! Realm(configuration: migration.config)

        return realm
    }

    static func shared(_ name: String = "Shared") -> Realm {
        var configuration = RealmConfiguration.configuration(name: name)
        configuration.objectTypes = [
            Bookmark.self,
            History.self
        ]
        
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
