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
    private let queue: DispatchQueue
    private let config: Realm.Configuration
    private let realm: Realm

    public init(queue: DispatchQueue = DispatchQueue(label: "com.RealmStore.syncQueue", qos: .background), realm: Realm) {
        self.queue = queue
        self.realm = realm
        self.config = realm.configuration
    }

    func performSync(_ callback: (Realm) -> Void) {
        if Thread.isMainThread {
            callback(realm)
        } else {
            dispatchPrecondition(condition: .notOnQueue(queue))
            queue.sync {
                autoreleasepool {
                    guard let realm = try? Realm(configuration: config) else { return }
                    callback(realm)
                }
            }
        }
    }
}

extension Wallet {
    class functional {}
}

extension Wallet.functional {
    static func realm(forAccount account: Wallet) -> Realm {
        let migration = DatabaseMigration(account: account)
        migration.perform()

        let realm = try! Realm(configuration: migration.config)

        let realmUrl = migration.config.fileURL!
        let realmUrls = [
            realmUrl,
            realmUrl.appendingPathExtension("lock"),
            realmUrl.appendingPathExtension("note"),
            realmUrl.appendingPathExtension("management")
        ]
        for each in realmUrls {
            try? FileManager.default.setAttributes([FileAttributeKey.protectionKey: FileProtectionType.none], ofItemAtPath: each.relativePath)
        }

        return realm
    }
}

extension Realm {
    static func shared(name: String = "Shared") -> Realm {
        let configuration = RealmConfiguration.configuration(name: name)
        return try! Realm(configuration: configuration)
    }

    public func safeWrite(_ block: (() throws -> Void)) throws {
        if isInWriteTransaction {
            try block()
        } else {
            try write(block)
        }
    }
}

protocol DetachableObject: AnyObject {
    func detached() -> Self
}

extension Object: DetachableObject {

    func detached() -> Self {
        let detached = type(of: self).init()
        for property in objectSchema.properties {
            guard let value = value(forKey: property.name) else { continue }

            if property.isArray == true {
                //Realm List property support
                let detachable = value as? DetachableObject
                detached.setValue(detachable?.detached(), forKey: property.name)
            } else if property.type == .object {
                //Realm Object property support
                let detachable = value as? DetachableObject
                detached.setValue(detachable?.detached(), forKey: property.name)
            } else {
                detached.setValue(value, forKey: property.name)
            }
        }
        return detached
    }
}

extension List: DetachableObject {
    func detached() -> List<Element> {
        let result = List<Element>()

        forEach {
            if let detachable = $0 as? DetachableObject {
                let detached = detachable.detached() as! Element
                result.append(detached)
            } else {
                result.append($0) //Primtives are pass by value; don't need to recreate
            }
        }

        return result
    }

    func toArray() -> [Element] {
        return Array(self.detached())
    }
}

extension Results {
    func toArray() -> [Element] {
        let result = List<Element>()

        forEach {
            result.append($0)
        }

        return Array(result.detached())
    }
}
