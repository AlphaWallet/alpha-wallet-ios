//
// Created by James Sangalli on 6/6/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import Alamofire
import SwiftyJSON

class GetContractInteractions {

    func getErc20Interactions(contractAddress: AlphaWallet.Address? = nil, address: AlphaWallet.Address, server: RPCServer, completion: @escaping ([Transaction]) -> Void) {
        let etherscanURL = server.etherscanAPIURLForERC20TxList(for: address)
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

    func getContractList(address: AlphaWallet.Address, server: RPCServer, erc20: Bool, completion: @escaping ([AlphaWallet.Address]) -> Void) {
        let etherscanURL: URL
        if erc20 {
            etherscanURL = server.etherscanAPIURLForERC20TxList(for: address)
        } else {
            etherscanURL = server.etherscanAPIURLForTransactionList(for: address)
        }
        Alamofire.request(etherscanURL).validate().responseJSON { response in
            switch response.result {
            case .success(let value):
                //Performance: process in background so UI don't have a chance of blocking if there's a long list of contracts
                DispatchQueue.global().async {
                    let json = JSON(value)
                    let contracts: [String] = json["result"].map { _, transactionJson in
                        if transactionJson["input"] != "0x" {
                            //every transaction that has input is by default a transaction to a contract
                            //Note: etherscan API only returns contractAddress for this call
                            //if it is an initialisation of a contract
                            if transactionJson["contractAddress"].description == "" {
                                return transactionJson["to"].description
                            } else {
                                return transactionJson["contractAddress"].description
                            }
                        }
                        return ""
                    }
                    let nonEmptyContracts = contracts.filter { !$0.isEmpty }
                    let uniqueNonEmptyContracts = Set(nonEmptyContracts).compactMap { AlphaWallet.Address(uncheckedAgainstNullAddress: $0) }
                    DispatchQueue.main.async {
                        completion(uniqueNonEmptyContracts)
                    }
                }
            case .failure(let error):
                print(error)
                completion([])
            }
        }
    }
}
