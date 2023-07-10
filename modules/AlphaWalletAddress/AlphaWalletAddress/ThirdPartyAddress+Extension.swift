// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import TrustKeystore

//TODO multiple versions of init() that accept address types from other libraries goes here. Anymore?

extension AlphaWallet.Address {
    public init(address: TrustKeystore.Address) {
        self = .ethereumAddress(eip55String: address.eip55String)
    }
}

extension TrustKeystore.Address {
    public init(address: AlphaWallet.Address) {
        self.init(uncheckedAgainstNullAddress: address.eip55String)!
    }
}
