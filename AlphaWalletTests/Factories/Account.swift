// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import TrustKeystore

extension Account {
    static func make(
        address: AlphaWallet.Address = .make(),
        url: URL = URL(fileURLWithPath: "")
    ) -> Account {
        return Account(
            address: Address(address: address),
            url: url
        )
    }
}
