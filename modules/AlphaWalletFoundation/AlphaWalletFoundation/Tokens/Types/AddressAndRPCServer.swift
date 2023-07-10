//
//  AddressAndRPCServer.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2021.
//

import Foundation

public struct AddressAndRPCServer: Hashable, Codable, CustomStringConvertible {
    public let address: AlphaWallet.Address
    public let server: RPCServer

    public init(address: AlphaWallet.Address, server: RPCServer) {
        self.address = address
        self.server = server
    }

    public var description: String {
        return "\(address.eip55String)-\(server)"
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(description)
    }
}
