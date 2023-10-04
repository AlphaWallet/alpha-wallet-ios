// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import AlphaWalletCore

public enum WalletOrigin: Int {
    case privateKey
    case hd
    case hardware
    case watch
}

public struct Wallet: Equatable, CustomStringConvertible {
    public let type: WalletType
    public let origin: WalletOrigin

    public var address: AlphaWallet.Address {
        return type.address
    }

    public var allowBackup: Bool {
        switch type {
        case .real:
            return true
        case .watch, .hardware:
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
        case .hardware:
            self.type = .hardware(address)
        case .watch:
            self.type = .watch(address)
        }
        self.origin = origin
    }
}

extension Wallet: Hashable { }
