// Copyright SIX DAY LLC. All rights reserved.

import Foundation

fileprivate let threadSafeForSubscribable = ThreadSafe(label: "org.alphawallet.swift.subscribable")
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
    private var _subscribers: [SubscribableKey: Subscription] = .init()
    private var _oneTimeSubscribers: [(T) -> Void] = []
    open var value: T? {
        get {
            return _value
        }
        set {
            _value = newValue
            threadSafeForSubscribable.performSync {
                for (_, f) in _subscribers {
                    f.callback(newValue)
                }

                if let value = value {
                    for f in _oneTimeSubscribers {
                        f(value)
                    }
                    _oneTimeSubscribers = []
                }
            }
        }
    }

    private let uuid = UUID()

    public init(_ value: T?) {
        _value = value
    }

    private struct Subscription {
        let callback: (T?) -> Void
    }

    @discardableResult open func subscribe(_ subscribe: @escaping (T?) -> Void) -> SubscribableKey {
        if let value = _value {
            subscribe(value)
        }
        let key = SubscribableKey()
        threadSafeForSubscribable.performSync {
            _subscribers[key] = Subscription(callback: subscribe)
        }

        return key
    }

    open func subscribeOnce(_ subscribe: @escaping (T) -> Void) {
        if let value = _value {
            subscribe(value)
        } else {
            threadSafeForSubscribable.performSync {
                _oneTimeSubscribers.append(subscribe)
            }
        }
    }

    public func unsubscribe(_ key: SubscribableKey) {
        threadSafeForSubscribable.performSync {
            _subscribers.removeValue(forKey: key)
        }
    }

    public func unsubscribeAll() {
        threadSafeForSubscribable.performSync {
            _subscribers.removeAll()
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
}
