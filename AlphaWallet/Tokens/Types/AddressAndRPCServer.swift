//
//  AddressAndRPCServer.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2021.
//

import UIKit

struct AddressAndRPCServer: Hashable, Codable, CustomStringConvertible {
    let address: AlphaWallet.Address
    let server: RPCServer

    var description: String {
        return "\(address.eip55String)-\(server)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(description)
    }
}