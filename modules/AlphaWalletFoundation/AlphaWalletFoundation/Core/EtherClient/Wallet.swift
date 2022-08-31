// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public enum WalletType: Equatable, Hashable, CustomStringConvertible {
    case real(AlphaWallet.Address)
    case watch(AlphaWallet.Address)

    public var description: String {
        switch self {
        case .real(let address):
            return ".real(\(address.eip55String))"
        case .watch(let address):
            return ".watch(\(address.eip55String))"
        }
    }
}

public enum WalletOrigin: Int {
    case privateKey
    case hd
    case watch
}

public struct Wallet: Equatable, CustomStringConvertible {
    public let type: WalletType
    public let origin: WalletOrigin
    
    public var address: AlphaWallet.Address {
        switch type {
        case .real(let account):
            return account
        case .watch(let address):
            return address
        }
    }

    public var allowBackup: Bool {
        switch type {
        case .real:
            return true
        case .watch:
            return false
        }
    }
    
    public var description: String {
        type.description
    }

    public init(address: AlphaWallet.Address, origin: WalletOrigin) {
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
