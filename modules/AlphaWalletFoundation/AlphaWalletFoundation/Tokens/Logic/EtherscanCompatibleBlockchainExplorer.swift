// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import SwiftyJSON
import Combine
import AlphaWalletCore
import BigInt
import AlphaWalletLogger
import Alamofire

class EtherscanCompatibleBlockchainExplorer: BlockchainExplorer {
    private let server: RPCServer
    private let transporter: ApiTransporter
    private let transactionBuilder: TransactionBuilder
    private let baseUrl: URL
    private let apiKey: String?
    private let defaultPagination = BlockBasedPagination(startBlock: nil, endBlock: nil)
    private let analytics: AnalyticsLogger

    init(server: RPCServer, transporter: ApiTransporter, transactionBuilder: TransactionBuilder, baseUrl: URL, apiKey: String?, analytics: AnalyticsLogger) {
        self.apiKey = apiKey
        self.baseUrl = baseUrl
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
            endBlock: pagination.endBlock,
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
            endBlock: pagination.endBlock,
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
        case .main, .classic, .xDai, .polygon, .binance_smart_chain, .binance_smart_chain_testnet, .callisto, .optimistic, .cronosMainnet, .cronosTestnet, .custom, .arbitrum, .palm, .palmTestnet, .optimismGoerli, .arbitrumGoerli, .avalanche, .avalanche_testnet, .sepolia:
            break
        case .goerli, .heco, .heco_testnet, .fantom, .fantom_testnet, .mumbai_testnet, .klaytnCypress, .klaytnBaobabTestnet, .ioTeX, .ioTeXTestnet, .okx:
            return .fail(PromiseError(error: BlockchainExplorerError.methodNotSupported))
        }

        let request = Request(
            baseUrl: baseUrl,
            startBlock: pagination.startBlock,
            endBlock: pagination.endBlock,
            apiKey: apiKey,
            walletAddress: walletAddress,
            action: .token1155tx)
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
                let (transactions, minBlockNumber, maxBlockNumber) = functional.extractBoundingBlockNumbers(fromTransactions: transactions)
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
                let (transactions, minBlockNumber, maxBlockNumber) = functional.extractBoundingBlockNumbers(fromTransactions: transactions)
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

    public func normalTransactions(walletAddress: AlphaWallet.Address,
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
                            let transactions = functional.filter(
                                transactions: $0.compactMap { $0 },
                                startBlock: pagination.startBlock,
                                endBlock: pagination.endBlock)

                            let (_, _, maxBlockNumber) = functional.extractBoundingBlockNumbers(fromTransactions: transactions)
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

        switch server {
        case .main, .classic, .goerli, .xDai, .polygon, .binance_smart_chain, .binance_smart_chain_testnet, .callisto, .optimistic, .cronosMainnet, .cronosTestnet, .custom, .arbitrum, .palm, .palmTestnet, .optimismGoerli, .arbitrumGoerli, .avalanche, .avalanche_testnet, .sepolia, .fantom, .fantom_testnet, .mumbai_testnet, .klaytnCypress, .klaytnBaobabTestnet, .ioTeX, .ioTeXTestnet, .okx:
            break
        case .heco, .heco_testnet:
            return .fail(PromiseError(error: BlockchainExplorerError.methodNotSupported))
        }

        return getErc1155Transactions(walletAddress: walletAddress, server: server, startBlock: pagination.startBlock)
            .flatMap { transactions -> AnyPublisher<TransactionsResponse, PromiseError> in
                let (transactions, minBlockNumber, maxBlockNumber) = functional.extractBoundingBlockNumbers(fromTransactions: transactions)
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
            .tryMap { functional.decodeTokenTransferTransactions(json: JSON($0.data), server: server, tokenType: .erc20) }
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
            action: .tokennfttx)
        let analytics = analytics
        let domainName = baseUrl.host!

        return transporter
            .dataTaskPublisher(request)
            .handleEvents(receiveOutput: { [server] in Self.log(response: $0, server: server, analytics: analytics, domainName: domainName) })
            .tryMap { functional.decodeTokenTransferTransactions(json: JSON($0.data), server: server, tokenType: .erc721) }
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
            action: .token1155tx)
        let analytics = analytics
        let domainName = baseUrl.host!

        return transporter
            .dataTaskPublisher(request)
            .handleEvents(receiveOutput: { [server] in Self.log(response: $0, server: server, analytics: analytics, domainName: domainName) })
            .tryMap { functional.decodeTokenTransferTransactions(json: JSON($0.data), server: server, tokenType: .erc1155) }
            .mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }

    private func backFillTransactionGroup(walletAddress: AlphaWallet.Address,
                                          transactions: [Transaction],
                                          startBlock: Int,
                                          endBlock: Int) -> AnyPublisher<[Transaction], PromiseError> {

        guard !transactions.isEmpty else { return .just([]) }
        let pagination = BlockBasedPagination(startBlock: startBlock, endBlock: endBlock)

        return normalTransactions(walletAddress: walletAddress, sortOrder: .asc, pagination: pagination)
            .map {
                functional.mergeTransactionOperationsForNormalTransactions(
                    transactions: transactions,
                    normalTransactions: $0.transactions)
            }.eraseToAnyPublisher()
    }

    func gasPriceEstimates() -> AnyPublisher<LegacyGasEstimates, PromiseError> {
        let request = GasOracleRequest(baseUrl: baseUrl, apiKey: apiKey)

        return transporter
            .dataTaskPublisher(request)
            .tryMap { try JSONDecoder().decode(EtherscanPriceEstimatesResponse.self, from: $0.data) }
            .compactMap { EtherscanPriceEstimates.bridgeToGasPriceEstimates(for: $0.result) }
            .map { estimates in
                LegacyGasEstimates(standard: BigUInt(estimates.standard), others: [
                    GasSpeed.slow: BigUInt(estimates.slow),
                    GasSpeed.fast: BigUInt(estimates.fast),
                    GasSpeed.rapid: BigUInt(estimates.rapid)
                ])
            }.mapError { PromiseError.some(error: $0) }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    fileprivate static func log(response: URLRequest.Response, server: RPCServer, analytics: AnalyticsLogger, domainName: String, caller: String = #function) {
        switch URLRequest.validate(statusCode: 200..<300, response: response.response) {
        case .failure:
            let json = try? JSON(response.data)
            infoLog("[API] request failure with status code: \(response.response.statusCode), json: \(json), server: \(server)", callerFunctionName: caller)
            let properties: [String: AnalyticsEventPropertyValue] = [Analytics.Properties.chain.rawValue: server.chainID, Analytics.Properties.domainName.rawValue: domainName, Analytics.Properties.code.rawValue: response.response.statusCode]
            analytics.log(error: Analytics.WebApiErrors.blockchainExplorerError, properties: properties)
        case .success:
            if let json = try? JSON(response.data), json["result"].stringValue == "Max rate limit reached" {
                infoLog("[API] request rate limited with status code: \(response.response.statusCode), json: \(json), server: \(server)", callerFunctionName: caller)
                let properties: [String: AnalyticsEventPropertyValue] = [Analytics.Properties.chain.rawValue: server.chainID, Analytics.Properties.domainName.rawValue: domainName, Analytics.Properties.code.rawValue: response.response.statusCode]
                analytics.log(error: Analytics.WebApiErrors.blockchainExplorerRateLimited, properties: properties)
            }
        }
    }
}

extension EtherscanCompatibleBlockchainExplorer {

    struct EtherscanPriceEstimatesResponse: Decodable {
        let result: EtherscanPriceEstimates
    }

    enum Action: String {
        case txlist
        case tokentx
        case tokennfttx
        case token1155tx
    }

    struct GasOracleRequest: URLRequestConvertible {
        let baseUrl: URL
        let apiKey: String?

        init(baseUrl: URL,
             apiKey: String? = nil) {

            self.baseUrl = baseUrl
            self.apiKey = apiKey
        }

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            var request = try URLRequest(url: baseUrl, method: .get)
            var params: Parameters = [
                "module": "gastracker",
                "action": "gasoracle"
            ]

            if let apiKey = apiKey {
                params["apikey"] = apiKey
            }

            request.allHTTPHeaderFields = [
                "Content-type": "application/json",
                "client": Bundle.main.bundleIdentifier ?? "",
                "client-build": Bundle.main.buildNumber ?? "",
            ]

            return try URLEncoding().encode(request, with: params)
        }
    }

    struct Request: URLRequestConvertible {
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
            self.sortOrder = sortOrder
            self.startBlock = startBlock
            self.endBlock = endBlock
            self.apiKey = apiKey
            self.walletAddress = walletAddress
        }

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            var request = try URLRequest(url: baseUrl, method: .get)
            var params: Parameters = [
                "module": "account",
                "action": action.rawValue,
                "address": walletAddress.eip55String
            ]
            if let startBlock = startBlock {
                params["startblock"] = String(startBlock)
            }

            if let endBlock = endBlock {
                params["endblock"] = String(endBlock)
            }

            if let apiKey = apiKey {
                params["apikey"] = apiKey
            }

            if let sortOrder = sortOrder {
                params["sort"] = sortOrder.rawValue
            }

            request.allHTTPHeaderFields = [
                "Content-Type": "application/json",
                "client": Bundle.main.bundleIdentifier ?? "",
                "client-build": Bundle.main.buildNumber ?? "",
            ]

            return try URLEncoding().encode(request, with: params)
        }
    }
}

extension EtherscanCompatibleBlockchainExplorer {
    enum functional {}
}

extension EtherscanCompatibleBlockchainExplorer.functional {

    //NOTE: some apis like https://api.hecoinfo.com/api? don't filter response to fit startBlock, endBlock, do it manually
    static func filter(transactions: [Transaction], startBlock: Int?, endBlock: Int?) -> [Transaction] {
        guard let startBlock = startBlock, let endBlock = endBlock else { return transactions }

        let range = min(startBlock, endBlock)...max(startBlock, endBlock)

        return transactions.filter { range.contains($0.blockNumber) }
    }

    static func extractBoundingBlockNumbers(fromTransactions transactions: [Transaction]) -> (transactions: [Transaction], min: Int, max: Int) {
        let blockNumbers = transactions.map(\.blockNumber)
        if let minBlockNumber = blockNumbers.min(), let maxBlockNumber = blockNumbers.max() {
            return (transactions: transactions, min: minBlockNumber, max: maxBlockNumber)
        } else {
            return (transactions: [], min: 0, max: 0)
        }
    }

    static func decodeTokenTransferTransactions(json: JSON, server: RPCServer, tokenType: Eip20TokenType) -> [Transaction] {
        let filteredResult: [(String, JSON)] = json["result"].filter { $0.1["to"].stringValue.hasPrefix("0x") }

        let transactions: [Transaction] = filteredResult.compactMap { result -> Transaction? in
            let transactionJson = result.1
                //Blockscout (and compatible like Polygon's) includes ERC721 transfers
            let operationType: OperationType

            switch tokenType {
            case .erc20:
                guard json["tokenID"].stringValue.isEmpty && json["tokenValue"].stringValue.isEmpty else { return nil }
                operationType = .erc20TokenTransfer
            case .erc721:
                guard json["tokenID"].stringValue.nonEmpty && json["tokenValue"].stringValue.isEmpty else { return nil }
                operationType = .erc721TokenTransfer
            case .erc1155:
                guard json["tokenID"].stringValue.nonEmpty && json["tokenValue"].stringValue.nonEmpty else { return nil }
                operationType = .erc1155TokenTransfer
            }

            //TODO: implement saving tokenValue
            let localizedTokenObj = LocalizedOperation(
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

            return Transaction(
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

    static func mergeTransactionOperationsForNormalTransactions(transactions: [Transaction], normalTransactions: [Transaction]) -> [Transaction] {
        var results: [Transaction] = .init()
        for each in transactions {
            //ERC20 transactions are expected to have operations because of the API we use to retrieve them from
            guard !each.localizedOperations.isEmpty else { continue }
            if var transaction = normalTransactions.first(where: { $0.blockNumber == each.blockNumber }) {
                transaction.isERC20Interaction = true
                transaction.localizedOperations = Array(Set(each.localizedOperations))
                results.append(transaction)
            } else {
                results.append(each)
            }
        }

        return results
    }

    static func mergeTransactionOperationsIntoSingleTransaction(_ transactions: [Transaction]) -> [Transaction] {
        var results: [Transaction] = .init()
        for each in transactions {
            if let index = results.firstIndex(where: { $0.blockNumber == each.blockNumber }) {
                var found = results[index]
                found.localizedOperations = Array(Set(found.localizedOperations + each.localizedOperations))
                results[index] = found
            } else {
                results.append(each)
            }
        }
        return results
    }
}
