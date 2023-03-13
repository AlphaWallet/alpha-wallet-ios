//
//  Erc20TokenTransferTransaction.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 07.03.2023.
//

import Foundation

struct Erc20TokenTransferTransaction {
    let hash: String
    let blockNumber: String
    let transactionIndex: String
    let timeStamp: String
    let nonce: String
    let from: String
    let to: String
    let value: String
    let gas: String
    let gasPrice: String
    let input: String
    let contractAddress: String
    let gasUsed: String
    let error: String?
    let isError: String?
    let tokenName: String
    let tokenSymbol: String
    let tokenDecimal: String

    ///
    ///It is possible for the etherscan.io API to return an empty `to` even if the transaction actually has a `to`. It doesn't seem to be linked to `"isError" = "1"`, because other transactions that fail (with isError="1") has a non-empty `to`.
    ///
    ///Eg. transaction with an empty `to` in API despite `to` is shown as non-empty in the etherscan.io web page:https: //ropsten.etherscan.io/tx/0x0c87d2acb0ecaf1221e599ad4f65edf77c97956d6534feb0afa68ee5c41c4e28
    ///
    ///So it must be a optional
    var toAddress: AlphaWallet.Address? {
        //TODO We use the unchecked version because it was easier to provide an Address instance this way. Good to remove it
        return AlphaWallet.Address(uncheckedAgainstNullAddress: to)
    }
}

extension Erc20TokenTransferTransaction: Decodable {
    enum CodingKeys: String, CodingKey {
        case hash
        case blockNumber
        case transactionIndex
        case timeStamp
        case nonce
        case from
        case to
        case value
        case gas
        case gasPrice
        case input
        case gasUsed
        case error
        case isError
        case contractAddress
        case tokenName
        case tokenSymbol
        case tokenDecimal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.hash = try container.decode(String.self, forKey: .hash, defaultValue: "")
        self.blockNumber = try container.decode(String.self, forKey: .blockNumber, defaultValue: "")
        self.transactionIndex = try container.decode(String.self, forKey: .transactionIndex, defaultValue: "")
        self.timeStamp = try container.decode(String.self, forKey: .timeStamp, defaultValue: "")
        self.nonce = try container.decode(String.self, forKey: .nonce, defaultValue: "")
        self.from = try container.decode(String.self, forKey: .from, defaultValue: "")
        self.to = try container.decode(String.self, forKey: .to, defaultValue: "")
        self.value = try container.decode(String.self, forKey: .value, defaultValue: "")
        self.gas = try container.decode(String.self, forKey: .gas, defaultValue: "")
        self.gasPrice = try container.decode(String.self, forKey: .gasPrice, defaultValue: "")
        self.input = try container.decode(String.self, forKey: .input, defaultValue: "")
        self.gasUsed = try container.decode(String.self, forKey: .gasUsed, defaultValue: "")
        self.error = try container.decodeIfPresent(String.self, forKey: .error)
        self.isError = try container.decodeIfPresent(String.self, forKey: .isError)
        self.contractAddress = try container.decode(String.self, forKey: .contractAddress, defaultValue: "")
        self.tokenName = try container.decode(String.self, forKey: .tokenName, defaultValue: "")
        self.tokenSymbol = try container.decode(String.self, forKey: .tokenSymbol, defaultValue: "")
        self.tokenDecimal = try container.decode(String.self, forKey: .tokenDecimal, defaultValue: "")
    }
}
