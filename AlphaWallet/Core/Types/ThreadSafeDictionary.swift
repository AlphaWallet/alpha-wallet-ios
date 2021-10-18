//
//  ThreadSafeDictionary.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.05.2021.
//

import UIKit

class ThreadSafeDictionary<Key: Hashable, Value> {
    fileprivate var cache = [Key: Value]()
    private let queue = DispatchQueue(label: "SynchronizedArrayAccess", qos: .background)

    subscript(server: Key) -> Value? {
        get {
            var element: Value?
            queue.sync { [weak self] in
                element = self?.cache[server]
            }
            return element
        }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.cache[server] = newValue
            }
        }
    }

    func removeAll() {
        queue.async(flags: .barrier) { [weak self] in
            self?.cache.removeAll()
        }
    }

    @discardableResult func removeValue(forKey key: Key) -> Value? {
        var element: Value?
        queue.sync { [weak self] in
            if let index = self?.cache.firstIndex(where: { $0.key == key }) {
                element = self?.cache.remove(at: index).value
            }
        }
        return element
    }

    var values: [Key: Value] {
        var elements: [Key: Value] = [:]
        queue.sync { [weak self] in
            elements = self?.cache ?? [:]
        }

        return elements
    }
}
