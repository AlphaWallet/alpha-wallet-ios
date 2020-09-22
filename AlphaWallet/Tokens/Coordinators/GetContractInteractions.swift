//
// Created by James Sangalli on 6/6/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import Alamofire
import SwiftyJSON

class GetContractInteractions {

    func getErc20Interactions(contractAddress: AlphaWallet.Address? = nil, address: AlphaWallet.Address, server: RPCServer, startBlock: Int? = nil, completion: @escaping ([Transaction]) -> Void) {
        guard var etherscanURL = server.etherscanAPIURLForERC20TxList(for: address, startBlock: startBlock) else { return }
        Alamofire.request(etherscanURL).validate().responseJSON { response in
            switch response.result {
            case .success(let value):
                //Performance: process in background so UI don't have a chance of blocking if there's a long list of contracts
                DispatchQueue.global().async {
                    let json = JSON(value)
                    let filteredResult: [(String, JSON)]
                    if let contractAddress = contractAddress {
                        //filter based on what contract you are after
                        filteredResult = json["result"].filter {
                            $0.1["contractAddress"].description == contractAddress.eip55String.lowercased()
                        }
                    } else {
                        filteredResult = json["result"].filter {
                            $0.1["to"].description.contains("0x")
                        }
                    }
                    let transactions: [Transaction] = filteredResult.map { result in
                        let transactionJson = result.1
                        let localizedTokenObj = LocalizedOperationObject(
                                from: transactionJson["from"].description,
                                to: transactionJson["to"].description,
                                contract: AlphaWallet.Address(uncheckedAgainstNullAddress: transactionJson["contractAddress"].description),
                                type: "erc20TokenTransfer",
                                value: transactionJson["value"].description,
                                symbol: transactionJson["tokenSymbol"].description,
                                name: transactionJson["tokenName"].description,
                                decimals: transactionJson["tokenDecimal"].intValue
                        )
                        return Transaction(
                                id: transactionJson["hash"].description,
                                server: server,
                                blockNumber: transactionJson["blockNumber"].intValue,
                                from: transactionJson["from"].description,
                                to: transactionJson["to"].description,
                                value: transactionJson["value"].description,
                                gas: transactionJson["gas"].description,
                                gasPrice: transactionJson["gasPrice"].description,
                                gasUsed: transactionJson["gasUsed"].description,
                                nonce: transactionJson["nonce"].description,
                                date: Date(timeIntervalSince1970: Double(string: transactionJson["timeStamp"].description) ?? Double(0)),
                                localizedOperations: [localizedTokenObj],
                                state: .completed,
                                isErc20Interaction: true
                        )
                    }
                    DispatchQueue.main.async {
                        completion(transactions)
                    }
                }
            case .failure(let error):
                print(error)
                completion([])
            }
        }
    }

    func getContractList(address: AlphaWallet.Address, server: RPCServer, startBlock: Int? = nil, erc20: Bool, completion: @escaping ([AlphaWallet.Address], Int?) -> Void) {
        let etherscanURL: URL
        if erc20 {
            if let url = server.etherscanAPIURLForERC20TxList(for: address, startBlock: startBlock) {
                etherscanURL = url
            } else {
                return
            }
        } else {
            if let url = server.etherscanAPIURLForTransactionList(for: address, startBlock: startBlock) {
                etherscanURL = url
            } else {
                return
            }
        }
        Alamofire.request(etherscanURL).validate().responseJSON { response in
            switch response.result {
            case .success(let value):
                //Performance: process in background so UI don't have a chance of blocking if there's a long list of contracts
                DispatchQueue.global().async {
                    let json = JSON(value)
                    let contracts: [(String, Int?)] = json["result"].map { _, transactionJson in
                        let blockNumber = transactionJson["blockNumber"].string.flatMap { Int($0) }
                        if transactionJson["input"] != "0x" {
                            //every transaction that has input is by default a transaction to a contract
                            //Note: etherscan API only returns contractAddress for this call
                            //if it is an initialisation of a contract
                            if transactionJson["contractAddress"].description == "" {
                                return (transactionJson["to"].description, blockNumber)
                            } else {
                                return (transactionJson["contractAddress"].description, blockNumber)
                            }
                        }
                        return ("", blockNumber)
                    }
                    let nonEmptyContracts = contracts
                            .map { $0.0 }
                            .filter { !$0.isEmpty }
                    let uniqueNonEmptyContracts = Set(nonEmptyContracts).compactMap { AlphaWallet.Address(uncheckedAgainstNullAddress: $0) }
                    let maxBlockNumber = contracts.compactMap { $0.1 } .max()
                    DispatchQueue.main.async {
                        completion(uniqueNonEmptyContracts, maxBlockNumber)
                    }
                }
            case .failure(let error):
                print(error)
                completion([], nil)
            }
        }
    }
}
