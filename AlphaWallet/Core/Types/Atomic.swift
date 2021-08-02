//
//  Atomic.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.05.2021.
//

import UIKit

@propertyWrapper
struct Atomic<Value> {

    private let lock = DispatchSemaphore(value: 1)
    private var value: Value

    init(default: Value) {
        self.value = `default`
    }

    var wrappedValue: Value {
        get {
            lock.wait()
            defer { lock.signal() }
            return value
        }
        set {
            lock.wait()
            value = newValue
            lock.signal()
        }
    }
}
