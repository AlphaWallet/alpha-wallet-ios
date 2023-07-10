// Copyright © 2023 Stormbird PTE. LTD.

import AlphaWalletAddress
import enum AlphaWalletCore.RPCServer

public struct AddressAndOptionalRPCServer: Hashable, Codable, CustomStringConvertible {
    public let address: AlphaWallet.Address
    public let server: RPCServer?

    public var description: String {
        if let server = server {
            return "\(address.eip55String)-\(server)"
        } else {
            return address.eip55String
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(description)
    }

    public init(address: AlphaWallet.Address, server: RPCServer?) {
        self.address = address
        self.server = server
    }
}

