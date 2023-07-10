//
//  Erc1155SafeTransferFrom.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 08.11.2022.
//

import Foundation
import AlphaWalletABI

public struct Erc1155SafeTransferFrom: ContractMethod {
    let recipient: AlphaWallet.Address
    let account: AlphaWallet.Address
    let tokenIdAndValue: TokenSelection

    public init(recipient: AlphaWallet.Address, account: AlphaWallet.Address, tokenIdAndValue: TokenSelection) {
        self.recipient = recipient
        self.account = account
        self.tokenIdAndValue = tokenIdAndValue
    }

    public func encodedABI() throws -> Data {
        let function = Function(name: "safeTransferFrom", parameters: [.address, .address, .uint(bits: 256), .uint(bits: 256), .dynamicBytes])
        let parameters: [Any] = [
            account,
            recipient,
            tokenIdAndValue.tokenId,
            tokenIdAndValue.value,
            Data()
        ]
        let encoder = ABIEncoder()
        try encoder.encode(function: function, arguments: parameters)

        return encoder.data
    }
}
