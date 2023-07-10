//
//  Erc875DropCurrency.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 08.11.2022.
//

import Foundation
import AlphaWalletABI
import BigInt

public struct Erc875DropCurrency: ContractMethod {
    let signedOrder: SignedOrder
    let v: UInt8
    let r: String
    let s: String
    let recipient: AlphaWallet.Address

    public init(signedOrder: SignedOrder, v: UInt8, r: String, s: String, recipient: AlphaWallet.Address) {
        self.signedOrder = signedOrder
        self.v = v
        self.r = r
        self.s = s
        self.recipient = recipient
    }

    public func encodedABI() throws -> Data {
        let parameters: [Any] = [
            signedOrder.order.nonce,
            signedOrder.order.expiry,
            signedOrder.order.count,
            BigUInt(v),
            Data(_hex: r),
            Data(_hex: s),
            recipient
        ]
        let functionEncoder = Function(name: "dropCurrency", parameters: [
            .uint(bits: 256),
            .uint(bits: 256),
            .uint(bits: 256),
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
