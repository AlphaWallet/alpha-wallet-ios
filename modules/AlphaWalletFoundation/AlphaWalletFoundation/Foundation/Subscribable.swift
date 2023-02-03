// Copyright SIX DAY LLC. All rights reserved.

import Foundation

//TODO probably should have an ID which is really good for debugging
open class Subscribable<T>: Hashable {
    public static func == (lhs: Subscribable<T>, rhs: Subscribable<T>) -> Bool {
        return lhs.uuid == rhs.uuid
    }

    public struct SubscribableKey: Hashable {
        let id = UUID()

        public static func == (lhs: SubscribableKey, rhs: SubscribableKey) -> Bool {
            return lhs.id == rhs.id
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    private var _value: T?
    private var _subscribers: AtomicDictionary<SubscribableKey, Subscription> = .init()
    private var _oneTimeSubscribers: AtomicArray<(T) -> Void> = .init()
    open var value: T? {
        return _value
    }

    private let uuid = UUID()

    public init(_ value: T?) {
        _value = value
    }

    private struct Subscription {
        let callback: (T?) -> Void
    }

    public func send(_ newValue: T?) {
        _value = newValue
        _subscribers.forEach { (_, f) in
            f.callback(newValue)
        }

        if let value = value {
            _oneTimeSubscribers.forEach { $0(value) }

            _oneTimeSubscribers.removeAll()
        }
    }

    @discardableResult open func subscribe(_ subscribe: @escaping (T?) -> Void) -> SubscribableKey {
        if let value = _value {
            subscribe(value)
        }
        let key = SubscribableKey()
        _subscribers[key] = Subscription(callback: subscribe)

        return key
    }

    open func subscribeOnce(_ subscribe: @escaping (T) -> Void) {
        if let value = _value {
            subscribe(value)
        } else {
            _oneTimeSubscribers.append(subscribe)
        }
    }

    public func unsubscribe(_ key: SubscribableKey) {
        _subscribers.removeValue(forKey: key)
    }

    public func unsubscribeAll() {
        _subscribers.removeAll()
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
}
