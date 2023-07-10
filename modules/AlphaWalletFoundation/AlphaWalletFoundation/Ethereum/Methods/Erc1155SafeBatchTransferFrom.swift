//
//  Erc1155SafeBatchTransferFrom.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 08.11.2022.
//

import Foundation
import AlphaWalletABI

public struct Erc1155SafeBatchTransferFrom: ContractMethod {
    let recipient: AlphaWallet.Address
    let account: AlphaWallet.Address
    let tokenIdsAndValues: [TokenSelection]

    public init(recipient: AlphaWallet.Address, account: AlphaWallet.Address, tokenIdsAndValues: [TokenSelection]) {
        self.recipient = recipient
        self.account = account
        self.tokenIdsAndValues = tokenIdsAndValues
    }

    public func encodedABI() throws -> Data {
        let tokenIds = tokenIdsAndValues.compactMap { $0.tokenId }
        let values = tokenIdsAndValues.compactMap { $0.value }
        let function = Function(name: "safeBatchTransferFrom", parameters: [
            .address,
            .address,
            .array(.uint(bits: 256), tokenIds.count),
            .array(.uint(bits: 256), values.count),
            .dynamicBytes
        ])

        let parameters: [Any] = [
            account,
            recipient,
            tokenIds,
            values,
            Data()
        ]
        let encoder = ABIEncoder()
        try encoder.encode(function: function, arguments: parameters)

        return encoder.data
    }
}
