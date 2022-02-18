//
//  ThreadSafeDictionary.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.05.2021.
//

import Foundation

public class ThreadSafeDictionary<Key: Hashable, Value> {
    private var cache = [Key: Value]()
    
    private let queue = DispatchQueue(label: "SynchronizedArrayAccess", qos: .background)

    public subscript(server: Key) -> Value? {
        get {
            var element: Value?
            dispatchPrecondition(condition: .notOnQueue(queue))
            queue.sync { [unowned self] in
                element = self.cache[server]
            }
            return element
        }
        set {
            dispatchPrecondition(condition: .notOnQueue(queue))
            queue.sync { [unowned self] in
                self.cache[server] = newValue
            }
        }
    }
    public init() {
        
    }

    public func removeAll() {
        dispatchPrecondition(condition: .notOnQueue(queue))
        queue.sync { [unowned self] in
            self.cache.removeAll()
        }
    }

    @discardableResult public func removeValue(forKey key: Key) -> Value? {
        var element: Value?
        dispatchPrecondition(condition: .notOnQueue(queue))
        queue.sync { [unowned self] in
            element = self.cache.firstIndex(where: { $0.key == key }).flatMap { self.cache.remove(at: $0).value }
        }
        return element
    }

    public var values: [Key: Value] {
        var elements: [Key: Value] = [:]
        dispatchPrecondition(condition: .notOnQueue(queue))
        queue.sync { [unowned self] in
            elements = self.cache
        }

        return elements
    }
}
