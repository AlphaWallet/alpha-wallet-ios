// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
@testable import AlphaWallet

extension AlphaWallet.Address {
    static func make(address: String = "0x1000000000000000000000000000000000000000") -> AlphaWallet.Address {
        return AlphaWallet.Address(string: address)!
    }

    static func makeStormBird(address: String = "0x007bEe82BDd9e866b2bd114780a47f2261C684E3") -> AlphaWallet.Address {
        return AlphaWallet.Address(string: address)!
    }
}
