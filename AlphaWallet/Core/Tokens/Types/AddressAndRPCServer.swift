//
//  AddressAndRPCServer.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2021.
//

import Foundation

public struct AddressAndRPCServer: Hashable, Codable, CustomStringConvertible {
    let address: AlphaWallet.Address
    let server: RPCServer

    public var description: String {
        return "\(address.eip55String)-\(server)"
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(description)
    }
}

public struct AddressAndOptionalRPCServer: Hashable, Codable, CustomStringConvertible {
    let address: AlphaWallet.Address
    let server: RPCServer?

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
}
