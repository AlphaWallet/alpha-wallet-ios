//
//  File.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 08.11.2022.
//

import Foundation
import BigInt

public struct Erc721SafeTransferFrom: ContractMethod {
    let recipient: AlphaWallet.Address
    let contractAddress: AlphaWallet.Address
    let account: AlphaWallet.Address
    let tokenId: BigUInt

    public init(recipient: AlphaWallet.Address, contractAddress: AlphaWallet.Address, account: AlphaWallet.Address, tokenId: BigUInt) {
        self.recipient = recipient
        self.contractAddress = contractAddress
        self.account = account
        self.tokenId = tokenId
    }

    public func encodedABI() throws -> Data {
        let function: Function
        let parameters: [Any]
        //NOTE: Not really good to do it here, maybe split
        if contractAddress.isLegacy721Contract {
            function = Function(name: "transfer", parameters: [.address, .uint(bits: 256)])
            parameters = [recipient, tokenId]
        } else {
            function = Function(name: "safeTransferFrom", parameters: [.address, .address, .uint(bits: 256)])
            parameters = [account, recipient, tokenId]
        }
        let encoder = ABIEncoder()
        try encoder.encode(function: function, arguments: parameters)

        return encoder.data
    }
}
