//
// Created by James Sangalli on 6/6/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import SwiftyJSON
import Combine
import AlphaWalletCore
import BigInt
import AlphaWalletLogger

/// Etherscan and Blockout api networking
class EtherscanCompatibleApiNetworking: ApiNetworking {
    private let walletAddress: AlphaWallet.Address
    private let server: RPCServer
    private let transporter: ApiTransporter
    private let transactionBuilder: TransactionBuilder

    init(server: RPCServer,
         wallet: Wallet,
         transporter: ApiTransporter,
         transactionBuilder: TransactionBuilder) {

        self.walletAddress = wallet.address
        self.transactionBuilder = transactionBuilder
        self.transporter = transporter
        self.server = server
    }

    func erc20TokenInteractions(walletAddress: AlphaWallet.Address,
                                startBlock: Int?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError> {

        let request = GetContractList(walletAddress: walletAddress, server: server, startBlock: startBlock, tokenType: .erc20)
        return transporter
            .dataTaskPublisher(request)
            .handleEvents(receiveOutput: { EtherscanCompatibleApiNetworking.log(response: $0) })
            .tryMap { UniqueNonEmptyContracts(json: try JSON(data: $0.data), tokenType: .erc20) }
            .mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }

    func erc721TokenInteractions(walletAddress: AlphaWallet.Address,
                                 startBlock: Int?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError> {

        let request = GetContractList(walletAddress: walletAddress, server: server, startBlock: startBlock, tokenType: .erc721)
        return transporter
            .dataTaskPublisher(request)
            .handleEvents(receiveOutput: { EtherscanCompatibleApiNetworking.log(response: $0) })
            .tryMap { UniqueNonEmptyContracts(json: try JSON(data: $0.data), tokenType: .erc721) }
            .mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }

    func erc1155TokenInteractions(walletAddress: AlphaWallet.Address,
                                  startBlock: Int?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError> {

        let request = GetContractList(walletAddress: walletAddress, server: server, startBlock: startBlock, tokenType: .erc1155)
        return transporter
            .dataTaskPublisher(request)
            .handleEvents(receiveOutput: { EtherscanCompatibleApiNetworking.log(response: $0) })
            .tryMap { UniqueNonEmptyContracts(json: try JSON(data: $0.data), tokenType: .erc1155) }
            .mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }

    func erc20TokenTransferTransactions(startBlock: Int? = nil) -> AnyPublisher<([TransactionInstance], Int), PromiseError> {
        return erc20TokenTransferTransactions(walletAddress: walletAddress, server: server, startBlock: startBlock)
            .flatMap { transactions -> AnyPublisher<([TransactionInstance], Int), PromiseError> in
                let (result, minBlockNumber, maxBlockNumber) = EtherscanCompatibleApiNetworking.functional.extractBoundingBlockNumbers(fromTransactions: transactions)
                return self.backFillTransactionGroup(result, startBlock: minBlockNumber, endBlock: maxBlockNumber)
                    .map { ($0, maxBlockNumber) }
                    .eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }

    func erc721TokenTransferTransactions(startBlock: Int? = nil) -> AnyPublisher<([TransactionInstance], Int), PromiseError> {
        return getErc721Transactions(walletAddress: walletAddress, server: server, startBlock: startBlock)
            .flatMap { transactions -> AnyPublisher<([TransactionInstance], Int), PromiseError> in
                let (result, minBlockNumber, maxBlockNumber) = EtherscanCompatibleApiNetworking.functional.extractBoundingBlockNumbers(fromTransactions: transactions)
                return self.backFillTransactionGroup(result, startBlock: minBlockNumber, endBlock: maxBlockNumber)
                    .map { ($0, maxBlockNumber) }
                    .eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }

    func normalTransactions(startBlock: Int, endBlock: Int = 999_999_999, sortOrder: GetTransactions.SortOrder) -> AnyPublisher<[TransactionInstance], PromiseError> {
        return transporter
            .dataTaskPublisher(GetTransactions(server: server, address: walletAddress, startBlock: startBlock, endBlock: endBlock, sortOrder: sortOrder))
            .handleEvents(receiveOutput: { EtherscanCompatibleApiNetworking.log(response: $0) })
            .mapError { PromiseError(error: $0) }
            .flatMap { [transactionBuilder] result -> AnyPublisher<[TransactionInstance], PromiseError> in
                if result.response.statusCode == 404 {
                    return .fail(.some(error: URLError(URLError.Code(rawValue: 404)))) // Clearer than a JSON deserialization error when it's a 404
                }

                do {
                    let promises = try JSONDecoder().decode(ArrayResponse<NormalTransaction>.self, from: result.data)
                        .result.map { transactionBuilder.buildTransaction(from: $0) }

                    return Publishers.MergeMany(promises)
                        .collect()
                        .map { $0.compactMap { $0 } }
                        .setFailureType(to: PromiseError.self)
                        .eraseToAnyPublisher()
                } catch {
                    return .fail(.some(error: error))
                }
            }.eraseToAnyPublisher()
    }

    func erc1155TokenTransferTransactions(startBlock: Int?) -> AnyPublisher<([TransactionInstance], Int), AlphaWalletCore.PromiseError> {
        return .empty()
    }

    func normalTransactions(walletAddress: AlphaWallet.Address,
                            pagination: TransactionsPagination) -> AnyPublisher<TransactionsResponse<TransactionInstance>, PromiseError> {
        return .empty()
    }

    func erc20TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                        pagination: TransactionsPagination) -> AnyPublisher<TransactionsResponse<TransactionInstance>, PromiseError> {
        return .empty()
    }

    func erc721TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                         pagination: TransactionsPagination) -> AnyPublisher<TransactionsResponse<TransactionInstance>, PromiseError> {
        return .empty()
    }

    func erc1155TokenTransferTransaction(walletAddress: AlphaWallet.Address,
                                         pagination: TransactionsPagination) -> AnyPublisher<TransactionsResponse<TransactionInstance>, PromiseError> {
        return .empty()
    }

    //TODO: rename this since it might include ERC721 (blockscout and compatible like Polygon's). Or can we make this really fetch ERC20, maybe by filtering the results?
    private func erc20TokenTransferTransactions(walletAddress: AlphaWallet.Address, server: RPCServer, startBlock: Int? = nil) -> AnyPublisher<[TransactionInstance], PromiseError> {
        return transporter
            .dataTaskPublisher(GetErc20TransactionsRequest(startBlock: startBlock, server: server, walletAddress: walletAddress))
            .handleEvents(receiveOutput: { EtherscanCompatibleApiNetworking.log(response: $0) })
            .tryMap { EtherscanCompatibleApiNetworking.functional.decodeTransactions(json: JSON($0.data), server: server) }
            .mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }

    private func getErc721Transactions(walletAddress: AlphaWallet.Address, server: RPCServer, startBlock: Int? = nil) -> AnyPublisher<[TransactionInstance], PromiseError> {
        return transporter
            .dataTaskPublisher(GetErc721TransactionsRequest(startBlock: startBlock, server: server, walletAddress: walletAddress))
            .handleEvents(receiveOutput: { EtherscanCompatibleApiNetworking.log(response: $0) })
            .tryMap { EtherscanCompatibleApiNetworking.functional.decodeTransactions(json: JSON($0.data), server: server) }
            .mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }

    private func backFillTransactionGroup(_ transactions: [TransactionInstance], startBlock: Int, endBlock: Int) -> AnyPublisher<[TransactionInstance], PromiseError> {
        guard !transactions.isEmpty else { return .just([]) }

        return normalTransactions(startBlock: startBlock, endBlock: endBlock, sortOrder: .asc)
            .map { filledTransactions -> [TransactionInstance] in
                var results: [TransactionInstance] = .init()
                for each in transactions {
                    //ERC20 transactions are expected to have operations because of the API we use to retrieve them from
                    guard !each.localizedOperations.isEmpty else { continue }
                    if var transaction = filledTransactions.first(where: { $0.blockNumber == each.blockNumber }) {
                        transaction.isERC20Interaction = true
                        transaction.localizedOperations = each.localizedOperations
                        results.append(transaction)
                    } else {
                        results.append(each)
                    }
                }
                return results
            }.eraseToAnyPublisher()
    }

    static func log(response: URLRequest.Response, caller: String = #function) {
        switch URLRequest.validate(statusCode: 200..<300, response: response.response) {
        case .failure:
            let json = try? JSON(response.data)
            let message = json?["message"].stringValue ?? ""
            infoLog("[API] request failure with status code: \(response.response.statusCode), message: \(message)", callerFunctionName: caller)
        case .success:
            break
        }
    }
}

extension EtherscanCompatibleApiNetworking {

    private struct GetContractList: URLRequestConvertible {
        let walletAddress: AlphaWallet.Address
        let server: RPCServer
        let startBlock: Int?
        let tokenType: Eip20TokenType

        func asURLRequest() throws -> URLRequest {
            let etherscanURL: URL
            switch tokenType {
            case .erc20:
                guard let url = server.getEtherscanURLForTokenTransactionHistory(for: walletAddress, startBlock: startBlock) else { throw URLError(.badURL) }
                return try URLRequest(url: url, method: .get)
            case .erc721:
                guard let url = server.getEtherscanURLForGeneralTransactionHistory(for: walletAddress, startBlock: startBlock) else { throw URLError(.badURL) }
                return try URLRequest(url: url, method: .get)
            case .erc1155:
                throw URLError(.badURL)
            }
        }
    }

    private struct GetErc20TransactionsRequest: URLRequestConvertible {
        let startBlock: Int?
        let server: RPCServer
        let walletAddress: AlphaWallet.Address

        func asURLRequest() throws -> URLRequest {
            guard let url = server.getEtherscanURLForTokenTransactionHistory(for: walletAddress, startBlock: startBlock) else { throw URLError(.badURL) }
            return try URLRequest(url: url, method: .get)
        }
    }

    private struct GetErc721TransactionsRequest: URLRequestConvertible {
        let startBlock: Int?
        let server: RPCServer
        let walletAddress: AlphaWallet.Address

        func asURLRequest() throws -> URLRequest {
            guard let url = server.getEtherscanURLForERC721TransactionHistory(for: walletAddress, startBlock: startBlock) else { throw URLError(.badURL) }
            return try URLRequest(url: url, method: .get)
        }
    }
}

extension EtherscanCompatibleApiNetworking {
    enum functional {}
}

extension EtherscanCompatibleApiNetworking.functional {

    static func extractBoundingBlockNumbers(fromTransactions transactions: [TransactionInstance]) -> (transactions: [TransactionInstance], min: Int, max: Int) {
        let blockNumbers = transactions.map(\.blockNumber)
        if let minBlockNumber = blockNumbers.min(), let maxBlockNumber = blockNumbers.max() {
            return (transactions: transactions, min: minBlockNumber, max: maxBlockNumber)
        } else {
            return (transactions: [], min: 0, max: 0)
        }
    }

    static func decodeTransactions(json: JSON, server: RPCServer) -> [TransactionInstance] {
        let filteredResult: [(String, JSON)] = json["result"].filter { $0.1["to"].stringValue.hasPrefix("0x") }

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
                    decimals: transactionJson["tokenDecimal"].intValue)

            let gasPrice = transactionJson["gasPrice"].string.flatMap { BigUInt($0) }.flatMap { GasPrice.legacy(gasPrice: $0) }

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
                    gasPrice: gasPrice,
                    gasUsed: transactionJson["gasUsed"].stringValue,
                    nonce: transactionJson["nonce"].stringValue,
                    date: Date(timeIntervalSince1970: transactionJson["timeStamp"].doubleValue),
                    localizedOperations: [localizedTokenObj],
                    //The API only returns successful transactions
                    state: .completed,
                    isErc20Interaction: true)
        }
        return mergeTransactionOperationsIntoSingleTransaction(transactions)
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
}
