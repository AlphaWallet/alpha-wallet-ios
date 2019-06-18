// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore

enum WalletType: Equatable {
    case real(Account)
    case watch(AlphaWallet.Address)
}

struct Wallet: Equatable {
    let type: WalletType

    var address: AlphaWallet.Address {
        switch type {
        case .real(let account):
            return AlphaWallet.Address(address: account.address)
        case .watch(let address):
            return address
        }
    }
}
