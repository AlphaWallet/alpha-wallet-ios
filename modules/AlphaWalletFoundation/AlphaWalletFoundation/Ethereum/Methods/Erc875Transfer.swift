//
//  Erc875Transfer.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 08.11.2022.
//

import Foundation
import AlphaWalletABI
import BigInt

public struct Erc875Transfer: ContractMethod {
    let contractAddress: AlphaWallet.Address
    let recipient: AlphaWallet.Address
    let indices: [UInt16]

    public init(contractAddress: AlphaWallet.Address, recipient: AlphaWallet.Address, indices: [UInt16]) {
        self.contractAddress = contractAddress
        self.recipient = recipient
        self.indices = indices
    }

    public func encodedABI() throws -> Data {
        let parameters: [Any] = [recipient, indices.map({ BigUInt($0) })]
        let arrayType: ABIType
        if contractAddress.isLegacy875Contract {
            arrayType = ABIType.uint(bits: 16)
        } else {
            arrayType = ABIType.uint(bits: 256)
        }
        let functionEncoder = Function(name: "transfer", parameters: [.address, .dynamicArray(arrayType)])
        let encoder = ABIEncoder()
        try encoder.encode(function: functionEncoder, arguments: parameters)

        return encoder.data
    }
}
