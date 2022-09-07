//
// Created by James Sangalli on 6/6/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import Alamofire
import PromiseKit
import SwiftyJSON

public class GetContractInteractions {
    struct E: Error {}

    private let queue: DispatchQueue

    public init(queue: DispatchQueue) {
        self.queue = queue
    }

    public func getErc20Interactions(walletAddress: AlphaWallet.Address, server: RPCServer, startBlock: Int? = nil) -> Promise<[TransactionInstance]> {
        return functional.getErc20Interactions(walletAddress: walletAddress, server: server, startBlock: startBlock, queue: queue)
    }

    public func getErc721Interactions(walletAddress: AlphaWallet.Address, server: RPCServer, startBlock: Int? = nil) -> Promise<[TransactionInstance]> {
        return functional.getErc721Interactions(walletAddress: walletAddress, server: server, startBlock: startBlock, queue: queue)
    }

    public func getContractList(walletAddress: AlphaWallet.Address, server: RPCServer, startBlock: Int? = nil, erc20: Bool) -> Promise<([AlphaWallet.Address], Int?)> {
        return functional.getContractList(walletAddress: walletAddress, server: server, startBlock: startBlock, erc20: erc20, queue: queue)
    }
}

extension GetContractInteractions {
    class functional {}
}

extension GetContractInteractions.functional {

    //TODO rename this since it might include ERC721 (blockscout and compatible like Polygon's). Or can we make this really fetch ERC20, maybe by filtering the results?
    static func getErc20Interactions(walletAddress: AlphaWallet.Address, server: RPCServer, startBlock: Int? = nil, queue: DispatchQueue) -> Promise<[TransactionInstance]> {
        guard let etherscanURL = server.getEtherscanURLForTokenTransactionHistory(for: walletAddress, startBlock: startBlock) else { return .value([]) }
        return firstly {
            Alamofire.request(etherscanURL).validate().responseJSON(queue: queue, options: [])
        }.map(on: queue) { rawJson, _ in
            guard let rawJson = rawJson as? [String: Any] else { throw GetContractInteractions.E() }
            let json = JSON(rawJson)

            //Performance: process in background so UI don't have a chance of blocking if there's a long list of contracts
            let filteredResult: [(String, JSON)] = json["result"].filter {
                $0.1["to"].stringValue.hasPrefix("0x")
            }

            let transactions: [TransactionInstance] = filteredResult.map { result in
                let transactionJson = result.1
                //Blockscout (and compatible like Polygon's) includes ERC721 transfers
                let operationType: OperationType
                //TODO check have tokenID + no "value", cos those might be ERC1155?
                if let tokenId = transactionJson["tokenID"].string, !tokenId.isEmpty {
                    operationType = .erc721TokenTransfer
                } else {
                    operationType = .erc20TokenTransfer
                }

                let localizedTokenObj = LocalizedOperationObjectInstance(
                        from: transactionJson["from"].stringValue,
                        to: transactionJson["to"].stringValue,
                        contract: AlphaWallet.Address(uncheckedAgainstNullAddress: transactionJson["contractAddress"].stringValue),
                        type: operationType.rawValue,
                        value: transactionJson["value"].stringValue,
                        tokenId: transactionJson["tokenID"].stringValue,
                        symbol: transactionJson["tokenSymbol"].stringValue,
                        name: transactionJson["tokenName"].stringValue,
                        decimals: transactionJson["tokenDecimal"].intValue
                )

                return TransactionInstance(
                        id: transactionJson["hash"].stringValue,
                        server: server,
                        blockNumber: transactionJson["blockNumber"].intValue,
                        transactionIndex: transactionJson["transactionIndex"].intValue,
                        from: transactionJson["from"].stringValue,
                        to: transactionJson["to"].stringValue,
                        //Must not set the value of the ERC20 token transferred as the native crypto value transferred
                        value: "0",
                        gas: transactionJson["gas"].stringValue,
                        gasPrice: transactionJson["gasPrice"].stringValue,
                        gasUsed: transactionJson["gasUsed"].stringValue,
                        nonce: transactionJson["nonce"].stringValue,
                        date: Date(timeIntervalSince1970: transactionJson["timeStamp"].doubleValue),
                        localizedOperations: [localizedTokenObj],
                        //The API only returns successful transactions
                        state: .completed,
                        isErc20Interaction: true
                )
            }
            return mergeTransactionOperationsIntoSingleTransaction(transactions)
        }
    }

    //TODO Almost a duplicate of the the ERC20 version. De-dup maybe?
    //TODO what's the point of passing in a queue here? Should be controlled by this class, not the user of this class
    static func getErc721Interactions(walletAddress: AlphaWallet.Address, server: RPCServer, startBlock: Int? = nil, queue: DispatchQueue) -> Promise<[TransactionInstance]> {
        guard let etherscanURL = server.getEtherscanURLForERC721TransactionHistory(for: walletAddress, startBlock: startBlock) else { return .value([]) }
        return firstly {
            Alamofire.request(etherscanURL).validate().responseJSON(queue: queue, options: [])
        }.map(on: queue) { rawJson, _ in
            guard let rawJson = rawJson as? [String: Any] else { throw GetContractInteractions.E() }
            let json = JSON(rawJson)

            //Performance: process in background so UI don't have a chance of blocking if there's a long list of contracts
            let filteredResult: [(String, JSON)] = json["result"].filter {
                $0.1["to"].stringValue.hasPrefix("0x")
            }

            let transactions: [TransactionInstance] = filteredResult.map { result in
                let transactionJson = result.1
                //Blockscout (and compatible like Polygon's) includes ERC721 transfers
                let operationType: OperationType
                //TODO check have tokenID + no "value", cos those might be ERC1155?
                if let tokenId = transactionJson["tokenID"].string, !tokenId.isEmpty {
                    operationType = .erc721TokenTransfer
                } else {
                    //TODO do we and do we need to filter these way since we only want ERC721?
                    operationType = .erc20TokenTransfer
                }

                let localizedTokenObj = LocalizedOperationObjectInstance(
                        from: transactionJson["from"].stringValue,
                        to: transactionJson["to"].stringValue,
                        contract: AlphaWallet.Address(uncheckedAgainstNullAddress: transactionJson["contractAddress"].stringValue),
                        type: operationType.rawValue,
                        value: transactionJson["value"].stringValue,
                        tokenId: transactionJson["tokenID"].stringValue,
                        symbol: transactionJson["tokenSymbol"].stringValue,
                        name: transactionJson["tokenName"].stringValue,
                        decimals: transactionJson["tokenDecimal"].intValue
                )

                return TransactionInstance(
                        id: transactionJson["hash"].stringValue,
                        server: server,
                        blockNumber: transactionJson["blockNumber"].intValue,
                        transactionIndex: transactionJson["transactionIndex"].intValue,
                        from: transactionJson["from"].stringValue,
                        to: transactionJson["to"].stringValue,
                        //Must not set the value of the ERC20 token transferred as the native crypto value transferred
                        value: "0",
                        gas: transactionJson["gas"].stringValue,
                        gasPrice: transactionJson["gasPrice"].stringValue,
                        gasUsed: transactionJson["gasUsed"].stringValue,
                        nonce: transactionJson["nonce"].stringValue,
                        date: Date(timeIntervalSince1970: transactionJson["timeStamp"].doubleValue),
                        localizedOperations: [localizedTokenObj],
                        //The API only returns successful transactions
                        state: .completed,
                        isErc20Interaction: true
                )
            }
            return mergeTransactionOperationsIntoSingleTransaction(transactions)
        }
    }

    static func mergeTransactionOperationsIntoSingleTransaction(_ transactions: [TransactionInstance]) -> [TransactionInstance] {
        var results: [TransactionInstance] = .init()
        for each in transactions {
            if let index = results.firstIndex(where: { $0.blockNumber == each.blockNumber }) {
                var found = results[index]
                found.localizedOperations.append(contentsOf: each.localizedOperations)
                results[index] = found
            } else {
                results.append(each)
            }
        }
        return results
    }

    static func getContractList(walletAddress: AlphaWallet.Address, server: RPCServer, startBlock: Int? = nil, erc20: Bool, queue: DispatchQueue) -> Promise<([AlphaWallet.Address], Int?)> {
        let etherscanURL: URL
        if erc20 {
            if let url = server.getEtherscanURLForTokenTransactionHistory(for: walletAddress, startBlock: startBlock) {
                etherscanURL = url
            } else {
                return Promise(error: GetContractInteractions.E())
            }
        } else {
            if let url = server.getEtherscanURLForGeneralTransactionHistory(for: walletAddress, startBlock: startBlock) {
                etherscanURL = url
            } else {
                return Promise(error: GetContractInteractions.E())
            }
        }
        return firstly {
            Alamofire.request(etherscanURL).validate().responseJSON(queue: queue)
        }.map(on: queue) { rawJson, _ in
            guard let rawJson = rawJson as? [String: Any] else { throw GetContractInteractions.E() }
            //Performance: process in background so UI don't have a chance of blocking if there's a long list of contracts
            let json = JSON(rawJson)
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
            let nonEmptyContracts = contracts
                    .map { $0.0 }
                    .filter { !$0.isEmpty }
            let uniqueNonEmptyContracts = Set(nonEmptyContracts).compactMap { AlphaWallet.Address(uncheckedAgainstNullAddress: $0) }
            let maxBlockNumber = contracts.compactMap { $0.1 } .max()
            return (uniqueNonEmptyContracts, maxBlockNumber)
        }
    }
}
