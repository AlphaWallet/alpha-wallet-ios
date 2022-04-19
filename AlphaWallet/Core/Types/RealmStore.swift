//
//  RealmStore.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 06.04.2022.
//

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
            queue.sync { [unowned self] in
                autoreleasepool {
                    let realm = try! Realm(configuration: config)
                    callback(realm)
                }
            }
        }
    }
}

extension Realm {
    public func safeWrite(_ block: (() throws -> Void)) throws {
        if isInWriteTransaction {
            try block()
        } else {
            try write(block)
        }
    }
}
