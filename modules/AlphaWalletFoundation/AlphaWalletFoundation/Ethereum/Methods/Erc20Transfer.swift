//
//  Erc20Transfer.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 08.11.2022.
//

import Foundation
import AlphaWalletABI
import BigInt

public struct Erc20Transfer: ContractMethod {
    let recipient: AlphaWallet.Address
    let value: BigUInt

    public init(recipient: AlphaWallet.Address, value: BigUInt) {
        self.recipient = recipient
        self.value = value
    }

    public func encodedABI() throws -> Data {
        let function = Function(name: "transfer", parameters: [ABIType.address, ABIType.uint(bits: 256)])
        //Note: be careful here with the BigUInt and BigInt, the type needs to be exact
        let encoder = ABIEncoder()
        try encoder.encode(function: function, arguments: [recipient, value])

        return encoder.data
    }
}
