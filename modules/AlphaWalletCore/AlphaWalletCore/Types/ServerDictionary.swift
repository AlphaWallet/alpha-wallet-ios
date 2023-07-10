// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

//This class removes the need to force unwrap in the client code when we access the contents using the subscript operator
//TODO probably have a special init() that better ensures we create a store with values for every RPCServer key?
public struct ServerDictionary<T> {
    private var backingStore: [RPCServer: T]

    public subscript(server: RPCServer) -> T {
        get {
            return backingStore[server]!
        }
        set(value) {
            backingStore[server] = value
        }
    }

    public var keys: Set<RPCServer> {
        Set(backingStore.keys)
    }

    public init() {
        self.backingStore = .init()
    }

    public init(_ anotherDictionary: [RPCServer: T]) {
        self.backingStore = anotherDictionary
    }

    public mutating func remove(at key: RPCServer) {
        backingStore.removeValue(forKey: key)
    }

    public var values: [T] {
        return Array(backingStore.values)
    }

    public var anyValue: T {
        return backingStore.values.first!
    }

    public var count: Int {
        return backingStore.count
    }

    public var isEmpty: Bool {
        return backingStore.isEmpty
    }

    public func mapValues<V>(_ transform: (T) throws -> V) rethrows -> ServerDictionary<V> {
        var result: ServerDictionary<V> = .init()
        let mappedBackingStore = try! backingStore.mapValues(transform)
        result.backingStore = mappedBackingStore
        return result
    }

    public func hasKey(_ server: RPCServer) -> Bool {
        backingStore.contains(where: { $0.key == server })
    }
}

extension ServerDictionary {
    //TODO we should reduce the need for calling this as it implies we didn't clean up the app properly when switching wallets or it could hide programming errors where we access resources for chains that aren't enabled
    public subscript(safe index: RPCServer) -> T? {
        return backingStore[index]
    }
}

extension ServerDictionary: Sequence {
    public func makeIterator() -> Dictionary<RPCServer, T>.Iterator {
        backingStore.makeIterator()
    }
}
