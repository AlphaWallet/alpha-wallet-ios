// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import AlphaWalletFoundation

extension Wallet {
    static func make(address: AlphaWallet.Address = .make(), origin: WalletOrigin = .hd) -> Wallet {
        return Wallet(address: address, origin: origin)
    }

    static func makeStormBird(address: AlphaWallet.Address = AlphaWallet.Address(string: "0x007bEe82BDd9e866b2bd114780a47f2261C684E3")!, origin: WalletOrigin = .hd) -> Wallet {
        return Wallet(address: address, origin: origin)
    }
}
