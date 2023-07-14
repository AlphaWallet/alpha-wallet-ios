// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import SwiftyJSON
import Combine
import AlphaWalletCore
import BigInt
import AlphaWalletLogger
import Alamofire

class BlockscoutBlockchainExplorer: BlockchainExplorer {
    private let server: RPCServer
    private let transporter: ApiTransporter
    private let transactionBuilder: TransactionBuilder
    private let apiKey: String?
    private let baseUrl: URL
    private let defaultPagination = BlockBasedPagination(startBlock: nil, endBlock: nil)
    private let analytics: AnalyticsLogger

    init(server: RPCServer, transporter: ApiTransporter, transactionBuilder: TransactionBuilder, apiKey: String?, baseUrl: URL, analytics: AnalyticsLogger) {
        self.baseUrl = baseUrl
        self.apiKey = apiKey
        self.transactionBuilder = transactionBuilder
        self.transporter = transporter
        self.server = server
        self.analytics = analytics
    }

    func erc20TokenInteractions(walletAddress: AlphaWallet.Address,
                                pagination: TransactionsPagination?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError> {

        guard let pagination = (pagination ?? defaultPagination) as? BlockBasedPagination else {
            return .fail(PromiseError(error: BlockchainExplorerError.paginationTypeNotSupported))
        }

        let request = Request(
            baseUrl: baseUrl,
            startBlock: pagination.startBlock,
            apiKey: apiKey,
            walletAddress: walletAddress,
            action: .tokentx)
        let analytics = analytics
        let domainName = baseUrl.host!

        return transporter
            .dataTaskPublisher(request)
            .handleEvents(receiveOutput: { [server] in Self.log(response: $0, server: server, analytics: analytics, domainName: domainName) })
            .tryMap { UniqueNonEmptyContracts(json: try JSON(data: $0.data), tokenType: .erc20) }
            .mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }

    func erc721TokenInteractions(walletAddress: AlphaWallet.Address,
                                 pagination: TransactionsPagination?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError> {

        guard let pagination = (pagination ?? defaultPagination) as? BlockBasedPagination else {
            return .fail(PromiseError(error: BlockchainExplorerError.paginationTypeNotSupported))
        }

        switch server {
        case .main, .classic, .goerli, .xDai, .polygon, .binance_smart_chain, .binance_smart_chain_testnet, .callisto, .optimistic, .cronosMainnet, .cronosTestnet, .custom, .arbitrum, .palm, .palmTestnet, .optimismGoerli, .arbitrumGoerli, .avalanche, .avalanche_testnet, .sepolia:
            break
        case .heco, .heco_testnet, .fantom, .fantom_testnet, .mumbai_testnet, .klaytnCypress, .klaytnBaobabTestnet, .ioTeX, .ioTeXTestnet, .okx:
            return .fail(PromiseError(error: BlockchainExplorerError.methodNotSupported))
        }

        let request = Request(
            baseUrl: baseUrl,
            startBlock: pagination.startBlock,
            apiKey: apiKey,
            walletAddress: walletAddress,
            action: .txlist)
        let analytics = analytics
        let domainName = baseUrl.host!

        return transporter
            .dataTaskPublisher(request)
            .handleEvents(receiveOutput: { [server] in Self.log(response: $0, server: server, analytics: analytics, domainName: domainName) })
            .tryMap { UniqueNonEmptyContracts(json: try JSON(data: $0.data), tokenType: .erc721) }
            .mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }

    func erc1155TokenInteractions(walletAddress: AlphaWallet.Address,
                                  pagination: TransactionsPagination?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError> {

        guard let pagination = (pagination ?? defaultPagination) as? BlockBasedPagination else {
            return .fail(PromiseError(error: BlockchainExplorerError.paginationTypeNotSupported))
        }

        switch server {
        case .main, .classic, .goerli, .xDai, .polygon, .binance_smart_chain, .binance_smart_chain_testnet, .callisto, .optimistic, .cronosMainnet, .cronosTestnet, .custom, .arbitrum, .palm, .palmTestnet, .optimismGoerli, .arbitrumGoerli, .avalanche, .avalanche_testnet, .sepolia:
            break
        case .heco, .heco_testnet, .fantom, .fantom_testnet, .mumbai_testnet, .klaytnCypress, .klaytnBaobabTestnet, .ioTeX, .ioTeXTestnet, .okx:
            return .fail(PromiseError(error: BlockchainExplorerError.methodNotSupported))
        }

        let request = Request(
            baseUrl: baseUrl,
            startBlock: pagination.startBlock,
            apiKey: apiKey,
            walletAddress: walletAddress,
            action: .txlist)
        let analytics = analytics
        let domainName = baseUrl.host!

        return transporter
            .dataTaskPublisher(request)
            .handleEvents(receiveOutput: { [server] in Self.log(response: $0, server: server, analytics: analytics, domainName: domainName) })
            .tryMap { UniqueNonEmptyContracts(json: try JSON(data: $0.data), tokenType: .erc1155) }
            .mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }

    func erc20TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                        pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError> {

        guard let pagination = (pagination ?? defaultPagination) as? BlockBasedPagination else {
            return .fail(PromiseError(error: BlockchainExplorerError.paginationTypeNotSupported))
        }

        return erc20TokenTransferTransactions(walletAddress: walletAddress, server: server, startBlock: pagination.startBlock)
            .flatMap { transactions -> AnyPublisher<TransactionsResponse, PromiseError> in
                let (transactions, minBlockNumber, maxBlockNumber) = EtherscanCompatibleBlockchainExplorer.functional.extractBoundingBlockNumbers(fromTransactions: transactions)
                return self.backFillTransactionGroup(walletAddress: walletAddress, transactions: transactions, startBlock: minBlockNumber, endBlock: maxBlockNumber)
                    .map {
                        if maxBlockNumber > 0 {
                            let nextPage = BlockBasedPagination(startBlock: maxBlockNumber + 1, endBlock: nil)
                            return TransactionsResponse(transactions: $0, nextPage: nextPage)
                        } else {
                            return TransactionsResponse(transactions: $0, nextPage: nil)
                        }
                    }.eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }

    func erc721TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                         pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError> {

        guard let pagination = (pagination ?? defaultPagination) as? BlockBasedPagination else {
            return .fail(PromiseError(error: BlockchainExplorerError.paginationTypeNotSupported))
        }

        return getErc721Transactions(walletAddress: walletAddress, server: server, startBlock: pagination.startBlock)
            .flatMap { transactions -> AnyPublisher<TransactionsResponse, PromiseError> in
                let (transactions, minBlockNumber, maxBlockNumber) = EtherscanCompatibleBlockchainExplorer.functional.extractBoundingBlockNumbers(fromTransactions: transactions)
                return self.backFillTransactionGroup(walletAddress: walletAddress, transactions: transactions, startBlock: minBlockNumber, endBlock: maxBlockNumber)
                    .map {
                        if maxBlockNumber > 0 {
                            let nextPage = BlockBasedPagination(startBlock: maxBlockNumber + 1, endBlock: nil)
                            return TransactionsResponse(transactions: $0, nextPage: nextPage)
                        } else {
                            return TransactionsResponse(transactions: $0, nextPage: nil)
                        }
                    }.eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }

    func normalTransactions(walletAddress: AlphaWallet.Address,
                            sortOrder: GetTransactions.SortOrder,
                            pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError> {

        guard let pagination = (pagination ?? defaultPagination) as? BlockBasedPagination else {
            return .fail(PromiseError(error: BlockchainExplorerError.paginationTypeNotSupported))
        }

        let request = Request(
            baseUrl: baseUrl,
            startBlock: pagination.startBlock,
            endBlock: pagination.endBlock,
            sortOrder: sortOrder,
            apiKey: apiKey,
            walletAddress: walletAddress,
            action: .txlist)
        let analytics = analytics
        let domainName = baseUrl.host!

        return transporter
            .dataTaskPublisher(request)
            .handleEvents(receiveOutput: { [server] in Self.log(response: $0, server: server, analytics: analytics, domainName: domainName) })
            .mapError { PromiseError(error: $0) }
            .flatMap { [transactionBuilder] result -> AnyPublisher<TransactionsResponse, PromiseError> in
                if result.response.statusCode == 404 {
                    return .fail(.some(error: URLError(URLError.Code(rawValue: 404)))) // Clearer than a JSON deserialization error when it's a 404
                }

                do {
                    let promises = try JSONDecoder().decode(ArrayResponse<NormalTransaction>.self, from: result.data)
                        .result.map { transactionBuilder.buildTransaction(from: $0) }

                    return Publishers.MergeMany(promises)
                        .collect()
                        .map {
                            let transactions = $0.compactMap { $0 }
                            let (_, _, maxBlockNumber) = EtherscanCompatibleBlockchainExplorer.functional.extractBoundingBlockNumbers(fromTransactions: transactions)
                            if maxBlockNumber > 0 {
                                let nextPage = BlockBasedPagination(startBlock: maxBlockNumber + 1, endBlock: nil)
                                return TransactionsResponse(transactions: transactions, nextPage: nextPage)
                            } else {
                                return TransactionsResponse(transactions: transactions, nextPage: nil)
                            }
                        }.setFailureType(to: PromiseError.self)
                        .eraseToAnyPublisher()
                } catch {
                    return .fail(.some(error: error))
                }
            }.eraseToAnyPublisher()
    }

    func erc1155TokenTransferTransaction(walletAddress: AlphaWallet.Address,
                                         pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError> {

        guard let pagination = (pagination ?? defaultPagination) as? BlockBasedPagination else {
            return .fail(PromiseError(error: BlockchainExplorerError.paginationTypeNotSupported))
        }

        return getErc1155Transactions(walletAddress: walletAddress, server: server, startBlock: pagination.startBlock)
            .flatMap { transactions -> AnyPublisher<TransactionsResponse, PromiseError> in
                let (transactions, minBlockNumber, maxBlockNumber) = EtherscanCompatibleBlockchainExplorer.functional.extractBoundingBlockNumbers(fromTransactions: transactions)
                return self.backFillTransactionGroup(walletAddress: walletAddress, transactions: transactions, startBlock: minBlockNumber, endBlock: maxBlockNumber)
                    .map {
                        if maxBlockNumber > 0 {
                            let nextPage = BlockBasedPagination(startBlock: maxBlockNumber + 1, endBlock: nil)
                            return TransactionsResponse(transactions: $0, nextPage: nextPage)
                        } else {
                            return TransactionsResponse(transactions: $0, nextPage: nil)
                        }
                    }.eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }

    private func erc20TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                                server: RPCServer,
                                                startBlock: Int? = nil) -> AnyPublisher<[Transaction], PromiseError> {

        let request = Request(
            baseUrl: baseUrl,
            startBlock: startBlock,
            apiKey: apiKey,
            walletAddress: walletAddress,
            action: .tokentx)
        let analytics = analytics
        let domainName = baseUrl.host!

        return transporter
            .dataTaskPublisher(request)
            .handleEvents(receiveOutput: { [server] in Self.log(response: $0, server: server, analytics: analytics, domainName: domainName) })
            .tryMap { EtherscanCompatibleBlockchainExplorer.functional.decodeTokenTransferTransactions(json: JSON($0.data), server: server, tokenType: .erc20) }
            .mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }

    private func getErc721Transactions(walletAddress: AlphaWallet.Address,
                                       server: RPCServer,
                                       startBlock: Int? = nil) -> AnyPublisher<[Transaction], PromiseError> {

        let request = Request(
            baseUrl: baseUrl,
            startBlock: startBlock,
            apiKey: apiKey,
            walletAddress: walletAddress,
            action: .tokentx)
        let analytics = analytics
        let domainName = baseUrl.host!

        return transporter
            .dataTaskPublisher(request)
            .handleEvents(receiveOutput: { [server] in Self.log(response: $0, server: server, analytics: analytics, domainName: domainName) })
            .tryMap { EtherscanCompatibleBlockchainExplorer.functional.decodeTokenTransferTransactions(json: JSON($0.data), server: server, tokenType: .erc721) }
            .mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }

    private func getErc1155Transactions(walletAddress: AlphaWallet.Address,
                                        server: RPCServer,
                                        startBlock: Int? = nil) -> AnyPublisher<[Transaction], PromiseError> {

        let request = Request(
            baseUrl: baseUrl,
            startBlock: startBlock,
            apiKey: apiKey,
            walletAddress: walletAddress,
            action: .tokentx)
        let analytics = analytics
        let domainName = baseUrl.host!

        return transporter
            .dataTaskPublisher(request)
            .handleEvents(receiveOutput: { [server] in Self.log(response: $0, server: server, analytics: analytics, domainName: domainName) })
            .tryMap { EtherscanCompatibleBlockchainExplorer.functional.decodeTokenTransferTransactions(json: JSON($0.data), server: server, tokenType: .erc1155) }
            .mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }

    func gasPriceEstimates() -> AnyPublisher<LegacyGasEstimates, PromiseError> {
        return .fail(PromiseError(error: BlockchainExplorerError.methodNotSupported))
    }

    private func backFillTransactionGroup(walletAddress: AlphaWallet.Address,
                                          transactions: [Transaction],
                                          startBlock: Int,
                                          endBlock: Int) -> AnyPublisher<[Transaction], PromiseError> {

        guard !transactions.isEmpty else { return .just([]) }
        let pagination = BlockBasedPagination(startBlock: startBlock, endBlock: endBlock)

        return normalTransactions(walletAddress: walletAddress, sortOrder: .asc, pagination: pagination)
            .map {
                EtherscanCompatibleBlockchainExplorer.functional.mergeTransactionOperationsForNormalTransactions(
                    transactions: transactions,
                    normalTransactions: $0.transactions)
            }.eraseToAnyPublisher()
    }

    fileprivate static func log(response: URLRequest.Response, server: RPCServer, analytics: AnalyticsLogger, domainName: String, caller: String = #function) {
        switch URLRequest.validate(statusCode: 200..<300, response: response.response) {
        case .failure:
            let json = try? JSON(response.data)
            infoLog("[API] request failure with status code: \(response.response.statusCode), json: \(json), server: \(server)", callerFunctionName: caller)
            let properties: [String: AnalyticsEventPropertyValue] = [Analytics.Properties.chain.rawValue: server.chainID, Analytics.Properties.domainName.rawValue: domainName, Analytics.Properties.code.rawValue: response.response.statusCode]
            analytics.log(error: Analytics.WebApiErrors.blockchainExplorerError, properties: properties)
        case .success:
            break
        }
    }
}

extension BlockscoutBlockchainExplorer {

    private enum Action: String {
        case txlist
        case tokentx
    }

    private struct Request: URLRequestConvertible {
        let baseUrl: URL
        let startBlock: Int?
        let endBlock: Int?
        let apiKey: String?
        let walletAddress: AlphaWallet.Address
        let sortOrder: GetTransactions.SortOrder?
        let action: Action

        init(baseUrl: URL,
             startBlock: Int? = nil,
             endBlock: Int? = nil,
             sortOrder: GetTransactions.SortOrder? = nil,
             apiKey: String? = nil,
             walletAddress: AlphaWallet.Address,
             action: Action) {

            self.action = action
            self.baseUrl = baseUrl
            self.startBlock = startBlock
            self.endBlock = endBlock
            self.apiKey = apiKey
            self.walletAddress = walletAddress
            self.sortOrder = sortOrder
        }

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            let request = try URLRequest(url: baseUrl, method: .get)
            var params: Parameters = [
                "module": "account",
                "action": action.rawValue,
                "address": walletAddress.eip55String
            ]
            if let startBlock = startBlock {
                params["start_block"] = String(startBlock)
            }

            if let endBlock = endBlock {
                params["end_block"] = String(endBlock)
            }

            if let apiKey = apiKey {
                params["apikey"] = apiKey
            }

            if let sortOrder = sortOrder {
                params["sort"] = sortOrder.rawValue
            }

            return try URLEncoding().encode(request, with: params)
        }
    }
}
