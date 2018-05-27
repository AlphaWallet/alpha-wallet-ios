// Copyright SIX DAY LLC. All rights reserved.

import Foundation

open class Subscribable<T> {
    private var _value: T?
    private var _subscribers: [(T?) -> Void] = []
    private var _oneTimeSubscribers: [(T) -> Void] = []
    open var value: T? {
        get {
            return _value
        }
        set {
            _value = newValue
            for f in _subscribers {
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

    open func subscribe(_ subscribe: @escaping (T?) -> Void) {
        if let value = _value {
            subscribe(value)
        }
        _subscribers.append(subscribe)
    }
    open func subscribeOnce(_ subscribe: @escaping (T) -> Void) {
        if let value = _value {
            subscribe(value)
        } else {
            _oneTimeSubscribers.append(subscribe)
        }
    }
}
