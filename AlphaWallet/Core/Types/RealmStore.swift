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
