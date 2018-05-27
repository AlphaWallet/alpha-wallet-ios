// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore
@testable import Trust

extension Wallet {
    static func make(
        type: WalletType = .real(.make())
    ) -> Wallet {
        return Wallet(
            type: type
        )
    }

    static func makeStormBird(
        type: WalletType = .real(Account(address: Address(string: "0x007bEe82BDd9e866b2bd114780a47f2261C684E3")!,
                                         url: URL(fileURLWithPath: "")))
    ) -> Wallet {
        return Wallet(
            type: type
        )
    }
}
