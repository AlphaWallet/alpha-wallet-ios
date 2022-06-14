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
    private let config: Realm.Configuration
    private let thread: RunLoopThread = .init()
    private let mainThreadRealm: Realm
    //NOTE: Making it as lazy removes blocking main thread (when init method get called), and we sure that backgroundThreadRealm always get called in thread.performSync() { context
    private lazy var backgroundThreadRealm: Realm = {
        guard let realm = try? Realm(configuration: config) else { fatalError("Failure to resolve background realm") }

        return realm
    }()

    public init(realm: Realm, name: String = "org.alphawallet.swift.realmStore") {
        self.mainThreadRealm = realm
        config = realm.configuration

        thread.name = name
        thread.start()
    }

    func performSync(_ callback: @escaping (Realm) -> Void) {
        if Thread.isMainThread {
            callback(mainThreadRealm)
        } else {
            thread.performSync() {
                callback(self.backgroundThreadRealm)
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
