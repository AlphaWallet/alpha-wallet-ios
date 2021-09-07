//
//  AddressAndRPCServer.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2021.
//

import UIKit

struct AddressAndRPCServer: Hashable, Codable {
    let address: AlphaWallet.Address
    let server: RPCServer
}

extension AddressAndRPCServer: Equatable {
    static func == (lhs: AddressAndRPCServer, rhs: AddressAndRPCServer) -> Bool {
        lhs.address.sameContract(as: rhs.address) && lhs.server == rhs.server
    }
}
