// Copyright SIX DAY LLC. All rights reserved.

import Foundation

//TODO probably should have an ID which is really good for debugging
open class Subscribable<T> {
    public struct SubscribableKey: Hashable {
        let id = UUID()
    }

    private var _value: T?
    private var _subscribers: [SubscribableKey: (T?) -> Void] = .init()
    private var _oneTimeSubscribers: [(T) -> Void] = []
    open var value: T? {
        get {
            return _value
        }
        set {
            _value = newValue
            for f in _subscribers.values {
                f(value)
            }

            if let value = value {
                for f in _oneTimeSubscribers {
                    f(value)
                }
                _oneTimeSubscribers = []
            }
        }
    }

    public init(_ value: T?) {
        _value = value
    }

    @discardableResult open func subscribe(_ subscribe: @escaping (T?) -> Void) -> SubscribableKey {
        if let value = _value {
            subscribe(value)
        }
        let key = SubscribableKey()
        _subscribers[key] = subscribe
        return key
    }
    open func subscribeOnce(_ subscribe: @escaping (T) -> Void) {
        if let value = _value {
            subscribe(value)
        } else {
            _oneTimeSubscribers.append(subscribe)
        }
    }

    func unsubscribe(_ key: SubscribableKey) {
        _subscribers.removeValue(forKey: key)
    }
}
