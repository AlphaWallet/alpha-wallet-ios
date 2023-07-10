//
//  Erc875SpawnPassTo.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 08.11.2022.
//

import Foundation
import AlphaWalletABI
import BigInt

public struct Erc875SpawnPassTo: ContractMethod {
    let expiry: BigUInt
    let tokenIds: [BigUInt]
    let v: UInt8
    let r: String
    let s: String
    let recipient: AlphaWallet.Address

    public init(expiry: BigUInt, tokenIds: [BigUInt], v: UInt8, r: String, s: String, recipient: AlphaWallet.Address) {
        self.expiry = expiry
        self.tokenIds = tokenIds
        self.v = v
        self.r = r
        self.s = s
        self.recipient = recipient
    }

    public func encodedABI() throws -> Data {
        let parameters: [Any] = [expiry, tokenIds, BigUInt(v), Data(_hex: r), Data(_hex: s), recipient]
        let functionEncoder = Function(name: "spawnPassTo", parameters: [
            .uint(bits: 256),
            .dynamicArray(.uint(bits: 256)),
            .uint(bits: 8),
            .bytes(32),
            .bytes(32),
            .address
        ])
        let encoder = ABIEncoder()
        try encoder.encode(function: functionEncoder, arguments: parameters)

        return encoder.data
    }
}
