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
