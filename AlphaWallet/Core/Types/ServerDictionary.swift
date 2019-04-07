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

    var values: [T] {
        return Array(backingStore.values)
    }

    var anyValue: T {
        return backingStore.values.first!
    }
}
