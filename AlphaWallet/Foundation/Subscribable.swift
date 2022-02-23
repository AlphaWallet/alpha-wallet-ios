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
    private var _subscribers: [SubscribableKey: Subscription] = .init()
    private var _oneTimeSubscribers: [(T) -> Void] = []
    open var value: T? {
        get {
            return _value
        }
        set {
            _value = newValue
            for (_, f) in _subscribers {
                if let q = f.queue {
                    q.async { f.callback(newValue) }
                } else {
                    f.callback(newValue)
                }
            }

            if let value = value {
                for f in _oneTimeSubscribers {
                    f(value)
                }
                _oneTimeSubscribers = []
            }
        }
    }

    private let uuid = UUID()

    public init(_ value: T?) {
        _value = value
    }

    private struct Subscription {
        let queue: DispatchQueue?
        let callback: (T?) -> Void
    }

    @discardableResult open func subscribe(_ subscribe: @escaping (T?) -> Void, on queue: DispatchQueue? = .none) -> SubscribableKey {
        if let value = _value {
            if let q = queue {
                q.async { subscribe(value) }
            } else {
                subscribe(value)
            }
        }
        let key = SubscribableKey()
        _subscribers[key] = Subscription(queue: queue, callback: subscribe)
        return key
    }

    static func merge<T>(_ elements: [Subscribable<T>], on queue: DispatchQueue? = .none) -> Subscribable<[T]> {
        let values = elements.compactMap { $0.value }
        let notifier = Subscribable<[T]>(values)

        for each in elements {
            each.subscribe { _ in
                if let queue = queue {
                    queue.async {
                        notifier.value = elements.compactMap { $0.value }
                    }
                } else {
                    notifier.value = elements.compactMap { $0.value }
                }
            }
        }

        return notifier
    }

    func map<V>(_ mapClosure: @escaping (T) -> V?, on queue: DispatchQueue? = .none) -> Subscribable<V> {
        let notifier = Subscribable<V>(nil)

        func updateNotifier(with value: T?, on queue: DispatchQueue?) {
            if let queue = queue {
                queue.async {
                    notifier.value = value.flatMap { mapClosure($0) }
                }
            } else {
                notifier.value = value.flatMap { mapClosure($0) }
            }
        }

        subscribe { value in
            updateNotifier(with: value, on: queue)
        }

        return notifier
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

    func unsubscribeAll() {
        _subscribers.removeAll()
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
}
