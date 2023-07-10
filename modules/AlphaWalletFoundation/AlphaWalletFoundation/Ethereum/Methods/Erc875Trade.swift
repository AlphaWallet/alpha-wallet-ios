//
//  Erc875Trade.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 08.11.2022.
//

import Foundation
import AlphaWalletABI
import BigInt

public struct Erc875Trade: ContractMethod {
    let contractAddress: AlphaWallet.Address
    let v: UInt8
    let r: String
    let s: String
    let expiry: BigUInt
    let indices: [UInt16]

    public init(contractAddress: AlphaWallet.Address, v: UInt8, r: String, s: String, expiry: BigUInt, indices: [UInt16]) {
        self.contractAddress = contractAddress
        self.v = v
        self.r = r
        self.s = s
        self.expiry = expiry
        self.indices = indices
    }

    public func encodedABI() throws -> Data {
        let parameters: [Any] = [
            expiry,
            indices.map({ BigUInt($0) }),
            BigUInt(v),
            Data(_hex: r),
            Data(_hex: s)
        ]

        let arrayType: ABIType
        if contractAddress.isLegacy875Contract {
            arrayType = ABIType.uint(bits: 16)
        } else {
            arrayType = ABIType.uint(bits: 256)
        }

        let functionEncoder = Function(name: "trade", parameters: [
            .uint(bits: 256),
            .dynamicArray(arrayType),
            .uint(bits: 8),
            .bytes(32),
            .bytes(32)
        ])
        let encoder = ABIEncoder()
        try encoder.encode(function: functionEncoder, arguments: parameters)

        return encoder.data
    }
}
