// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import TrustKeystore
import web3swift

extension AlphaWallet.Address {
    //TODO multiple versions of init() that accept address types from other libraries goes here. Anymore?
    init(address: EthereumAddress) {
        self = .ethereumAddress(eip55String: address.address)
    }

    init(address: Address) {
        self = .ethereumAddress(eip55String: address.eip55String)
    }
}

extension EthereumAddress {
    init(address: AlphaWallet.Address) {
        self.init(address.eip55String)!
    }
}

extension TrustKeystore.Address {
    init(address: AlphaWallet.Address) {
        self.init(uncheckedAgainstNullAddress: address.eip55String)!
    }
}
