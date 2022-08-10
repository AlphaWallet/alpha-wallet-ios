// Copyright SIX DAY LLC. All rights reserved.

import Foundation

enum WalletType: Equatable, Hashable, CustomStringConvertible {
    case real(AlphaWallet.Address)
    case watch(AlphaWallet.Address)

    var description: String {
        switch self {
        case .real(let address):
            return ".real(\(address.eip55String))"
        case .watch(let address):
            return ".watch(\(address.eip55String))"
        }
    }
}

enum WalletOrigin: Int {
    case privateKey
    case hd
    case watch
}

struct Wallet: Equatable, CustomStringConvertible {
    let type: WalletType
    let origin: WalletOrigin
    
    var address: AlphaWallet.Address {
        switch type {
        case .real(let account):
            return account
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
    
    var description: String {
        type.description
    }

    init(address: AlphaWallet.Address, origin: WalletOrigin) {
        switch origin {
        case .privateKey, .hd:
            self.type = .real(address)
        case .watch:
            self.type = .watch(address)
        }
        self.origin = origin
    }
}

extension Wallet: Hashable { }
