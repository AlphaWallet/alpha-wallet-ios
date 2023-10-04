// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress

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
