// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import TrustKeystore

extension EthereumAccount {
    static func make(address: AlphaWallet.Address = .make()) -> EthereumAccount {
        return .init(address: address)
    }
}
