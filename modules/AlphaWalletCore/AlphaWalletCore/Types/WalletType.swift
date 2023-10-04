// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress

public enum WalletType: Equatable, Hashable, CustomStringConvertible {
    case real(AlphaWallet.Address)
    case watch(AlphaWallet.Address)
    case hardware(AlphaWallet.Address)

    public var description: String {
        switch self {
        case .real(let address):
            return ".real(\(address.eip55String))"
        case .watch(let address):
            return ".watch(\(address.eip55String))"
        case .hardware(let address):
            return ".hardware(\(address.eip55String))"
        }
    }

    public var address: AlphaWallet.Address {
        switch self {
        case .real(let address):
            return address
        case .watch(let address):
            return address
        case .hardware(let address):
            return address
        }
    }
}
