// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

//This class removes the need to force unwrap in the client code when we access the contents using the subscript operator
//TODO probably have a special init() that better ensures we create a store with values for every RPCServer key?
struct ServerDictionary<T> {
    private var backingStore = [RPCServer: T]()

    subscript(server: RPCServer) -> T {
        get {
            return backingStore[server]!
        }
        set(value) {
            backingStore[server] = value
        }
    }

    var keys: Set<RPCServer> {
        Set(backingStore.keys)
    }

    mutating func remove(at key: RPCServer) {
        backingStore.removeValue(forKey: key)
    }

    subscript(safe server: RPCServer) -> T? {
        get {
            return backingStore[server]
        }
        set(value) {
            backingStore[server] = value
        }
    }

    var values: [T] {
        return Array(backingStore.values)
    }

    var anyValue: T {
        return backingStore.values.first!
    }

    var count: Int {
        return backingStore.count
    }

    var isEmpty: Bool {
        return backingStore.isEmpty
    }

    func mapValues<V>(_ transform: (T) throws -> V) rethrows -> ServerDictionary<V> {
        var result: ServerDictionary<V> = .init()
        let mappedBackingStore = try! backingStore.mapValues(transform)
        result.backingStore = mappedBackingStore
        return result
    }

    func hasKey(_ server: RPCServer) -> Bool {
        backingStore.contains(where: { $0.key == server })
    }
}

extension ServerDictionary: Sequence {
    func makeIterator() -> Dictionary<RPCServer, T>.Iterator {
        backingStore.makeIterator()
    }
}
