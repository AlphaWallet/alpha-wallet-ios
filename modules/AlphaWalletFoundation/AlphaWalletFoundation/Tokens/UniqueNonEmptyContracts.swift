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
    init(json: JSON) {
        let contracts: [(String, Int?)] = json["result"].map { _, transactionJson in
            let blockNumber = transactionJson["blockNumber"].string.flatMap { Int($0) }
            if transactionJson["input"] != "0x" {
                //every transaction that has input is by default a transaction to a contract
                //Note: etherscan API only returns contractAddress for this call
                //if it is an initialisation of a contract
                if transactionJson["contractAddress"].stringValue == "" {
                    return (transactionJson["to"].stringValue, blockNumber)
                } else {
                    return (transactionJson["contractAddress"].stringValue, blockNumber)
                }
            }
            return ("", blockNumber)
        }
        let nonEmptyContracts = contracts.map { $0.0 }.filter { !$0.isEmpty }

        uniqueNonEmptyContracts = Set(nonEmptyContracts).compactMap { AlphaWallet.Address(uncheckedAgainstNullAddress: $0) }
        maxBlockNumber = contracts.compactMap { $0.1 }.max()
    }

}
