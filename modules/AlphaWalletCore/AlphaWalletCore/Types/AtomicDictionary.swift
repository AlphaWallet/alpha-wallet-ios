//
//  AtomicDictionary.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.05.2021.
//

import Foundation

public class AtomicDictionary<Key: Hashable, Value> {
    private var cache = [Key: Value]()
    private let queue: DispatchQueue

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

    public subscript(server: Key, default defaultValue: @autoclosure () -> Value) -> Value {
        return self[server] ?? defaultValue()
    }

    public init(queue: DispatchQueue = DispatchQueue(label: "org.alphawallet.swift.atomicDictionary", qos: .background), value: [Key: Value] = [:]) {
        self.queue = queue
        self.cache = value
    }

    public func set(value: [Key: Value]) {
        dispatchPrecondition(condition: .notOnQueue(queue))
        queue.sync { [unowned self] in
            self.cache = value
        }
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

    public var count: Int {
        return values.count
    }

    public var values: [Key: Value] {
        var elements: [Key: Value] = [:]
        dispatchPrecondition(condition: .notOnQueue(queue))
        queue.sync { [unowned self] in
            elements = self.cache
        }

        return elements
    }

    public func removeAll(body: (_ key: Key) -> Bool) {
        dispatchPrecondition(condition: .notOnQueue(queue))
        queue.sync { [unowned self] in
            let items = self.cache.filter { body($0.key) }
            items.forEach { self.cache.removeValue(forKey: $0.key) }
        }
    }

    public func forEach(body: ((key: Key, value: Value)) -> Void) {
        dispatchPrecondition(condition: .notOnQueue(queue))
        queue.sync { [unowned self] in
            self.cache.forEach(body)
        }
    }

    public func contains(where closure: ((_ key: Key, _ value: Value) -> Bool)) -> Bool {
        var value: Bool = false
        dispatchPrecondition(condition: .notOnQueue(queue))
        queue.sync { [unowned self] in
            value = self.cache.contains(where: closure)
        }

        return value
    }
}
