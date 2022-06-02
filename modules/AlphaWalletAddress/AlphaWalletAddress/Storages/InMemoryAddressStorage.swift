//
//  InMemoryAddressStorage.swift
//  AlphaWalletAddress
//
//  Created by Vladyslav Shepitko on 02.06.2022.
//

import Foundation
import AlphaWalletCore

public class InMemoryAddressStorage: AddressStorage {
    private var cache: AtomicDictionary<AddressKey, AlphaWallet.Address>

    public var allValues: [AddressKey: AlphaWallet.Address] {
        cache.values
    }

    public var count: Int {
        cache.values.count
    }

    public init(values: [AddressKey: AlphaWallet.Address] = [:]) {
        cache = .init(value: values)
    }

    public subscript(key: AddressKey) -> AlphaWallet.Address? {
        get { cache[key] }
        set { cache[key] = newValue }
    } 
}
