//
//  UniqueNonEmptyContracts.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 06.03.2023.
//

import Foundation
import SwiftyJSON

public struct UniqueNonEmptyContracts {
    let uniqueNonEmptyContracts: [AlphaWallet.Address]
    let maxBlockNumber: Int?
}

struct UniqueNonEmptyContractsDecoder {
    func decode(transactions: [NormalTransaction]) -> UniqueNonEmptyContracts {
        let contracts = transactions.map { tx -> (String, Int?) in
            let blockNumber = Int(tx.blockNumber)
            if tx.input != "0x" {
                //every transaction that has input is by default a transaction to a contract
                //Note: etherscan API only returns contractAddress for this call
                //if it is an initialisation of a contract
                if tx.contractAddress == "" {
                    return (tx.to, blockNumber)
                } else {
                    return (tx.contractAddress, blockNumber)
                }
            }
            return ("", blockNumber)
        }
        let nonEmptyContracts = contracts.map { $0.0 }.filter { !$0.isEmpty }

        let uniqueNonEmptyContracts = Set(nonEmptyContracts).compactMap { AlphaWallet.Address(uncheckedAgainstNullAddress: $0) }
        let maxBlockNumber = contracts.compactMap { $0.1 }.max()

        return .init(uniqueNonEmptyContracts: uniqueNonEmptyContracts, maxBlockNumber: maxBlockNumber)
    }
}

extension UniqueNonEmptyContracts {
    init(json: JSON, tokenType: Eip20TokenType) {
        let contracts: [(String, Int?)] = json["result"].compactMap { _, json -> (String, Int?)? in
            let blockNumber = json["blockNumber"].string.flatMap { Int($0) }
            //NOTE: safe check to avoid incompatible contract matching with token type, blockout api returns erc20 and erc721 for same url, so we need to filter retults
            switch tokenType {
            case .erc20:
                guard json["tokenID"].string == nil else { return nil }
            case .erc721:
                guard json["tokenID"].stringValue.nonEmpty else { return nil }
            case .erc1155:
                guard json["tokenID"].stringValue.nonEmpty && json["tokenValue"].stringValue.nonEmpty else { return nil }
            }

            if json["input"] != "0x" {
                //every transaction that has input is by default a transaction to a contract
                //Note: etherscan API only returns contractAddress for this call
                //if it is an initialisation of a contract
                if json["contractAddress"].stringValue == "" {
                    return (json["to"].stringValue, blockNumber)
                } else {
                    return (json["contractAddress"].stringValue, blockNumber)
                }
            }
            return ("", blockNumber)
        }
        let nonEmptyContracts = contracts.map { $0.0 }.filter { !$0.isEmpty }

        uniqueNonEmptyContracts = Set(nonEmptyContracts).compactMap { AlphaWallet.Address(uncheckedAgainstNullAddress: $0) }
        maxBlockNumber = contracts.compactMap { $0.1 }.max()
    }

}
