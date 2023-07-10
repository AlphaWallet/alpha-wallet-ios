//
//  File.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 08.11.2022.
//

import Foundation
import AlphaWalletABI
import BigInt

public struct Erc721SafeTransferFrom: ContractMethod {
    let recipient: AlphaWallet.Address
    let account: AlphaWallet.Address
    let tokenId: BigUInt

    public init(recipient: AlphaWallet.Address, account: AlphaWallet.Address, tokenId: BigUInt) {
        self.recipient = recipient
        self.account = account
        self.tokenId = tokenId
    }

    public func encodedABI() throws -> Data {
        let function = Function(name: "safeTransferFrom", parameters: [.address, .address, .uint(bits: 256)])
        let encoder = ABIEncoder()
        try encoder.encode(function: function, arguments: [account, recipient, tokenId])

        return encoder.data
    }
}

public struct Erc721TransferFrom: ContractMethod {
    let recipient: AlphaWallet.Address
    let tokenId: BigUInt

    public init(recipient: AlphaWallet.Address, tokenId: BigUInt) {
        self.recipient = recipient
        self.tokenId = tokenId
    }

    public func encodedABI() throws -> Data {
        let function: Function = Function(name: "transfer", parameters: [.address, .uint(bits: 256)])
        let encoder = ABIEncoder()
        try encoder.encode(function: function, arguments: [recipient, tokenId])

        return encoder.data
    }
}
