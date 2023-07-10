//
//  Erc20Approve.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 08.11.2022.
//

import Foundation
import AlphaWalletABI
import BigInt

public struct Erc20Approve: ContractMethod {
    let spender: AlphaWallet.Address
    let value: BigUInt

    public init(spender: AlphaWallet.Address, value: BigUInt) {
        self.spender = spender
        self.value = value
    }

    public func encodedABI() throws -> Data {
        let function = Function(name: "approve", parameters: [ABIType.address, ABIType.uint(bits: 256)])
        //Note: be careful here with the BigUInt and BigInt, the type needs to be exact
        let encoder = ABIEncoder()
        try encoder.encode(function: function, arguments: [spender, value])

        return encoder.data
    }
}
