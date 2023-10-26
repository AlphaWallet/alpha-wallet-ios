// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import SwiftyJSON
import Combine
import AlphaWalletCore
import BigInt
import AlphaWalletLogger
import Alamofire

// swiftlint:disable type_body_length
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
        let delay = self.randomDelay()
        let request = Request(baseUrl: baseUrl, startBlock: pagination.startBlock, endBlock: pagination.endBlock, apiKey: apiKey, walletAddress: walletAddress, action: .tokentx, delay: delay)
        let analytics = analytics
        let domainName = baseUrl.host!

        return Just(Void())
                .delay(for: .seconds(delay), scheduler: DispatchQueue.main)
                .setFailureType(to: SessionTaskError.self)
                .flatMap { _ in self.transporter.dataTaskPublisher(request) }
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

        if Self.serverSupportsFetchingNftTransactions(server) {
            //no-op
        } else {
            return .fail(PromiseError(error: BlockchainExplorerError.methodNotSupported))
        }

        let delay = self.randomDelay()
        let request = Request(baseUrl: baseUrl, startBlock: pagination.startBlock, endBlock: pagination.endBlock, apiKey: apiKey, walletAddress: walletAddress, action: .tokennfttx, delay: delay)
        let analytics = analytics
        let domainName = baseUrl.host!

        return Just(Void())
                .delay(for: .seconds(delay), scheduler: DispatchQueue.main)
                .setFailureType(to: SessionTaskError.self)
                .flatMap { _ in self.transporter.dataTaskPublisher(request) }
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

        if functional.serverSupportsFetchingErc1155Transactions(server) {
            //no-op
        } else {
            return .fail(PromiseError(error: BlockchainExplorerError.methodNotSupported))
        }

        let delay = self.randomDelay()
        let request = Request(baseUrl: baseUrl, startBlock: pagination.startBlock, endBlock: pagination.endBlock, apiKey: apiKey, walletAddress: walletAddress, action: .token1155tx, delay: delay)
        let analytics = analytics
        let domainName = baseUrl.host!

        return Just(Void())
                .delay(for: .seconds(delay), scheduler: DispatchQueue.main)
                .setFailureType(to: SessionTaskError.self)
                .flatMap { _ in self.transporter.dataTaskPublisher(request) }
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
                let (transactions, minBlockNumber, maxBlockNumber) = Self.extractBoundingBlockNumbers(fromTransactions: transactions)
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
                let (transactions, minBlockNumber, maxBlockNumber) = Self.extractBoundingBlockNumbers(fromTransactions: transactions)
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

        let delay = self.randomDelay()
        let request = Request(baseUrl: baseUrl, startBlock: pagination.startBlock, endBlock: pagination.endBlock, sortOrder: sortOrder, apiKey: apiKey, walletAddress: walletAddress, action: .txlist, delay: delay)
        let analytics = analytics
        let domainName = baseUrl.host!

        return Just(Void())
                .delay(for: .seconds(delay), scheduler: DispatchQueue.main)
                .setFailureType(to: SessionTaskError.self)
                .flatMap { _ in self.transporter.dataTaskPublisher(request) }
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
                                    let (_, _, maxBlockNumber) = Self.extractBoundingBlockNumbers(fromTransactions: transactions)
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

        if functional.serverSupportsFetchingErc1155Transactions(server) {
            //no-op
        } else {
            return .fail(PromiseError(error: BlockchainExplorerError.methodNotSupported))
        }

        return getErc1155Transactions(walletAddress: walletAddress, server: server, startBlock: pagination.startBlock)
            .flatMap { transactions -> AnyPublisher<TransactionsResponse, PromiseError> in
                let (transactions, minBlockNumber, maxBlockNumber) = Self.extractBoundingBlockNumbers(fromTransactions: transactions)
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

        let delay = self.randomDelay()
        let request = Request(baseUrl: baseUrl, startBlock: startBlock, apiKey: apiKey, walletAddress: walletAddress, action: .tokentx, delay: delay)
        let analytics = analytics
        let domainName = baseUrl.host!

        return Just(Void())
                .delay(for: .seconds(delay), scheduler: DispatchQueue.main)
                .setFailureType(to: SessionTaskError.self)
                .flatMap { _ in self.transporter.dataTaskPublisher(request) }
                .handleEvents(receiveOutput: { [server] in Self.log(response: $0, server: server, analytics: analytics, domainName: domainName) })
                .tryMap { Self.decodeTokenTransferTransactions(json: JSON($0.data), server: server, tokenType: .erc20) }
                .mapError { PromiseError.some(error: $0) }
                .eraseToAnyPublisher()
    }

    private func getErc721Transactions(walletAddress: AlphaWallet.Address,
                                       server: RPCServer,
                                       startBlock: Int? = nil) -> AnyPublisher<[Transaction], PromiseError> {
        if Self.serverSupportsFetchingNftTransactions(server) {
            //no-op
        } else {
            return .fail(PromiseError(error: BlockchainExplorerError.methodNotSupported))
        }

        let delay = self.randomDelay()
        let request = Request(baseUrl: baseUrl, startBlock: startBlock, apiKey: apiKey, walletAddress: walletAddress, action: .tokennfttx, delay: delay)
        let analytics = analytics
        let domainName = baseUrl.host!

        return Just(Void())
                .delay(for: .seconds(delay), scheduler: DispatchQueue.main)
                .setFailureType(to: SessionTaskError.self)
                .flatMap { _ in self.transporter.dataTaskPublisher(request) }
                .handleEvents(receiveOutput: { [server] in Self.log(response: $0, server: server, analytics: analytics, domainName: domainName) })
                .tryMap { Self.decodeTokenTransferTransactions(json: JSON($0.data), server: server, tokenType: .erc721) }
                .mapError { PromiseError.some(error: $0) }
                .eraseToAnyPublisher()
    }

    private func getErc1155Transactions(walletAddress: AlphaWallet.Address,
                                        server: RPCServer,
                                        startBlock: Int? = nil) -> AnyPublisher<[Transaction], PromiseError> {
        if functional.serverSupportsFetchingErc1155Transactions(server) {
            //no-op
        } else {
            return .fail(PromiseError(error: BlockchainExplorerError.methodNotSupported))
        }

        let delay = self.randomDelay()
        let request = Request(baseUrl: baseUrl, startBlock: startBlock, apiKey: apiKey, walletAddress: walletAddress, action: .token1155tx, delay: delay)
        let analytics = analytics
        let domainName = baseUrl.host!

        return Just(Void())
                .delay(for: .seconds(delay), scheduler: DispatchQueue.main)
                .setFailureType(to: SessionTaskError.self)
                .flatMap { _ in self.transporter.dataTaskPublisher(request) }
                .handleEvents(receiveOutput: { [server] in Self.log(response: $0, server: server, analytics: analytics, domainName: domainName) })
                .tryMap { Self.decodeTokenTransferTransactions(json: JSON($0.data), server: server, tokenType: .erc1155) }
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
                Self.mergeTransactionOperationsForNormalTransactions(
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
            var properties: [String: AnalyticsEventPropertyValue] = [Analytics.Properties.chain.rawValue: server.chainID, Analytics.Properties.domainName.rawValue: domainName, Analytics.Properties.code.rawValue: response.response.statusCode]
            //Taking the `result` is intentional for Etherscan-compatible, since message is probably "NOTOK"
            if let message = json?["result"].stringValue, !message.isEmpty {
                properties[Analytics.Properties.message.rawValue] = message
            }
            analytics.log(error: Analytics.WebApiErrors.blockchainExplorerError, properties: properties)
        case .success:
            if let json = try? JSON(response.data) {
                //Etherscan doesn't return 429
                if json["result"].stringValue == "Max rate limit reached" {
                    infoLog("[API] request rate limited with status code: \(response.response.statusCode), json: \(json), server: \(server)", callerFunctionName: caller)
                    let properties: [String: AnalyticsEventPropertyValue] = [Analytics.Properties.chain.rawValue: server.chainID, Analytics.Properties.domainName.rawValue: domainName, Analytics.Properties.code.rawValue: response.response.statusCode]
                    analytics.log(error: Analytics.WebApiErrors.blockchainExplorerRateLimited, properties: properties)
                } else if json["message"].stringValue == "NOTOK" {
                    //TODO this prints the API key, maybe we can mask it, but it's not critical since it isn't user data and is easy to pull from the app binary
                    infoLog("[API] request NOTOK with json: \(json.rawString()), server: \(server) url: \(response.response.url?.absoluteString)", callerFunctionName: caller)
                    let properties: [String: AnalyticsEventPropertyValue] = [Analytics.Properties.chain.rawValue: server.chainID, Analytics.Properties.domainName.rawValue: domainName, Analytics.Properties.code.rawValue: response.response.statusCode, Analytics.Properties.message.rawValue: json["result"].stringValue]
                    analytics.log(error: Analytics.WebApiErrors.blockchainExplorerError, properties: properties)
                }
            }
        }
    }

    //For avoid being rate limited
    private func randomDelay() -> Int {
        Int.random(in: 4...30)
    }

    static func extractBoundingBlockNumbers(fromTransactions transactions: [Transaction]) -> (transactions: [Transaction], min: Int, max: Int) {
        let blockNumbers = transactions.map(\.blockNumber)
        if let minBlockNumber = blockNumbers.min(), let maxBlockNumber = blockNumbers.max() {
            return (transactions: transactions, min: minBlockNumber, max: maxBlockNumber)
        } else {
            return (transactions: [], min: 0, max: 0)
        }
    }

    static func decodeTokenTransferTransactions(json: JSON, server: RPCServer, tokenType: EipTokenType) -> [Transaction] {
        let filteredResult: [(String, JSON)] = json["result"].filter { $0.1["to"].stringValue.hasPrefix("0x") }
        let transactions: [Transaction] = filteredResult.compactMap { result -> Transaction? in
            let transactionJson = result.1
            //Blockscout (and compatible like Polygon's) includes ERC721 transfers
            let operationType: OperationType

            switch tokenType {
            case .erc20:
                guard transactionJson["tokenID"].stringValue.isEmpty && transactionJson["tokenValue"].stringValue.isEmpty else { return nil }
                operationType = .erc20TokenTransfer
            case .erc721:
                guard transactionJson["tokenID"].stringValue.nonEmpty && transactionJson["tokenValue"].stringValue.isEmpty else { return nil }
                operationType = .erc721TokenTransfer
            case .erc1155:
                guard transactionJson["tokenID"].stringValue.nonEmpty && transactionJson["tokenValue"].stringValue.nonEmpty else { return nil }
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

        return functional.mergeTransactionOperationsIntoSingleTransaction(transactions)
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

    //TODO should move this to where the blockchain APIs are defined so we can update them in lock-step?
    static func serverSupportsFetchingNftTransactions(_ server: RPCServer) -> Bool {
        switch server {
        case .main, .polygon, .binance_smart_chain, .binance_smart_chain_testnet, .optimistic, .cronosMainnet, .arbitrum, .arbitrumGoerli, .avalanche, .avalanche_testnet, .heco, .heco_testnet, .sepolia:
            return true
        case .goerli, .fantom, .fantom_testnet, .mumbai_testnet, .klaytnCypress, .klaytnBaobabTestnet, .ioTeX, .ioTeXTestnet, .okx, .classic, .xDai, .callisto, .cronosTestnet, .palm, .palmTestnet, .optimismGoerli:
            return false
        case .custom(let customRpc):
            switch customRpc.etherscanCompatibleType {
            case .etherscan:
                return true
            case .blockscout, .unknown:
                return false
            }
        }
    }
}
// swiftlint:enable type_body_length

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
        //This is just displayed as part of the URL for debugging
        let delay: Int

        init(baseUrl: URL, startBlock: Int? = nil, endBlock: Int? = nil, sortOrder: GetTransactions.SortOrder? = nil, apiKey: String? = nil, walletAddress: AlphaWallet.Address, action: Action, delay: Int = 0) {
            self.action = action
            self.baseUrl = baseUrl
            self.sortOrder = sortOrder
            self.startBlock = startBlock
            self.endBlock = endBlock
            self.apiKey = apiKey
            self.walletAddress = walletAddress
            self.delay = delay
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

            if AlphaWallet.Device.isSimulator {
                //Helpful for debugging rate limiting since we can see the delay applied in the URL itself
                params["delay"] = delay
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

fileprivate extension EtherscanCompatibleBlockchainExplorer.functional {
    //NOTE: some apis like https://api.hecoinfo.com/api? don't filter response to fit startBlock, endBlock, do it manually
    static func filter(transactions: [Transaction], startBlock: Int?, endBlock: Int?) -> [Transaction] {
        guard let startBlock = startBlock, let endBlock = endBlock else { return transactions }

        let range = min(startBlock, endBlock)...max(startBlock, endBlock)

        return transactions.filter { range.contains($0.blockNumber) }
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

    //TODO should move this to where the blockchain APIs are defined so we can update them in lock-step?
    static func serverSupportsFetchingErc1155Transactions(_ server: RPCServer) -> Bool {
        switch server {
        case .main, .polygon, .binance_smart_chain, .binance_smart_chain_testnet, .optimistic, .cronosMainnet, .arbitrum, .avalanche, .avalanche_testnet:
            return true
        case .goerli, .heco, .heco_testnet, .fantom, .fantom_testnet, .mumbai_testnet, .klaytnCypress, .klaytnBaobabTestnet, .ioTeX, .ioTeXTestnet, .okx, .sepolia, .arbitrumGoerli, .classic, .xDai, .callisto, .cronosTestnet, .palm, .palmTestnet, .optimismGoerli, .custom:
            return false
        }
    }
}
