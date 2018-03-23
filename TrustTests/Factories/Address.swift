// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import Trust
import TrustKeystore

extension Address {
    static func make(
        address: String = "0x1000000000000000000000000000000000000000"
    ) -> Address {
        return Address(
            string: address
        )!
    }

    static func makeStormBird(
        address: String = "0x007bEe82BDd9e866b2bd114780a47f2261C684E3"
        ) -> Address {
        return Address(
            string: address
            )!
    }
}
