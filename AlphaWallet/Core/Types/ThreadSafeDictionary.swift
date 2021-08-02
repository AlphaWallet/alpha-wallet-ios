//
//  ThreadSafeDictionary.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.05.2021.
//

import UIKit

class ThreadSafeDictionary<Key: Hashable, Value> {
    fileprivate var cache = [Key: Value]()
    private let queue = DispatchQueue(label: "SynchronizedArrayAccess", attributes: .concurrent)

    subscript(server: Key) -> Value? {
        get {
            var element: Value?
            queue.sync {
                element = cache[server]
            }
            return element
        }
        set {
            queue.async(flags: .barrier) {
                self.cache[server] = newValue
            }
        }
    }

    func removeAll() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }

    @discardableResult func removeValue(forKey key: Key) -> Value? {
        var element: Value?
        queue.sync {
            if let index = cache.firstIndex(where: { $0.key == key }) {
                element = cache.remove(at: index).value
            }
        }
        return element
    }

    var value: [Key: Value] {
        return cache
    }
}
