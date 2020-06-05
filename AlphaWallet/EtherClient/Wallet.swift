// Copyright SIX DAY LLC. All rights reserved.

import Foundation

enum WalletType: Equatable {
    case real(EthereumAccount)
    case watch(AlphaWallet.Address)
}

struct Wallet: Equatable {
    let type: WalletType

    var address: AlphaWallet.Address {
        switch type {
        case .real(let account):
            return account.address
        case .watch(let address):
            return address
        }
    }
    
    var allowBackup: Bool {
        switch type {
        case .real:
            return true
        case .watch:
            return false
        }
    }
}
