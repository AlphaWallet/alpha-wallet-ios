// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore

enum WalletType: Equatable {
    case real(Account)
    case watch(Address)
}

struct Wallet: Equatable {
    let type: WalletType

    var address: Address {
        switch type {
        case .real(let account):
            return account.address
        case .watch(let address):
            return address
        }
    }
}
