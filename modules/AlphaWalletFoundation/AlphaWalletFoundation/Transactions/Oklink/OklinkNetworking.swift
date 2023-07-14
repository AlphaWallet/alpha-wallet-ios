// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletLogger
import SwiftyJSON

//NOTE: as api dosn't return localized operation contract, symbol and decimal for transfer transactions, fetch them from rpc node
// swiftlint:disable type_body_length
public class OklinkBlockchainExplorer: BlockchainExplorer {
    private static var allHTTPHeaderFields: HTTPHeaders = .init([
        "Content-type": "application/json",
        "client": Bundle.main.bundleIdentifier ?? "",
        "client-build": Bundle.main.buildNumber ?? "",
    ])

    private let server: RPCServer
    private let baseUrl: URL = URL(string: "https://www.oklink.com")!
    private let apiKey: String?
    private let transporter: ApiTransporter
    private let paginationFilter = TransactionPageBasedPaginationFilter()
    private let ercTokenProvider: TokenProviderType
    private let transactionBuilder: TransactionBuilder
    private let defaultPagination = PageBasedTransactionsPagination(page: 0, lastFetched: [], limit: 50)
    private let analytics: AnalyticsLogger

    public init(server: RPCServer, apiKey: String?, transporter: ApiTransporter, ercTokenProvider: TokenProviderType, transactionBuilder: TransactionBuilder, analytics: AnalyticsLogger) {
        self.transactionBuilder = transactionBuilder
        self.ercTokenProvider = ercTokenProvider
        self.server = server
        self.apiKey = apiKey
        self.transporter = transporter
        self.analytics = analytics
    }

    public func gasPriceEstimates() -> AnyPublisher<LegacyGasEstimates, PromiseError> {
        return .fail(PromiseError(error: BlockchainExplorerError.methodNotSupported))
    }

    public func normalTransactions(walletAddress: AlphaWallet.Address,
                                   sortOrder: GetTransactions.SortOrder,
                                   pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError> {

        guard let pagination = (pagination ?? defaultPagination) as? PageBasedTransactionsPagination else {
            return .fail(PromiseError(error: BlockchainExplorerError.paginationTypeNotSupported))
        }

        let request = TransactionsRequest(
            baseUrl: baseUrl,
            walletAddress: walletAddress,
            page: pagination.page,
            limit: pagination.limit,
            apiKey: apiKey ?? "",
            chainShortName: server.okLinkChainShortName,
            protocolType: .transaction,
            headers: Self.allHTTPHeaderFields)

        let decoder = NormalTransactionListDecoder(pagination: pagination, paginationFilter: paginationFilter)
        let analytics = analytics
        let domainName = baseUrl.host!

        return transporter.dataTaskPublisher(request)
            .handleEvents(receiveOutput: { [server] in Self.log(response: $0, server: server, analytics: analytics, domainName: domainName) })
            .tryMap { try decoder.decode(data: $0.data) }
            .mapError { PromiseError(error: $0) }
            .flatMap { response in
                self.buildTransactions(transactions: response.transactions)
                    .map {
                        return TransactionsResponse(
                            transactions: Covalent.ToNativeTransactionMapper.mergeTransactionOperationsIntoSingleTransaction($0),
                            nextPage: response.nextPage)
                    }
            }.eraseToAnyPublisher()
    }

    private func buildTransactions(transactions: [NormalTransaction]) -> AnyPublisher<[Transaction], PromiseError> {
        let publishers = transactions.map { transactionBuilder.buildTransaction(from: $0) }

        return Publishers.MergeMany(publishers)
           .collect()
           .map { $0.compactMap { $0 } }
           .setFailureType(to: PromiseError.self)
           .eraseToAnyPublisher()
    }

    public func erc20TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                               pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError> {

        guard let pagination = (pagination ?? defaultPagination) as? PageBasedTransactionsPagination else {
            return .fail(PromiseError(error: BlockchainExplorerError.paginationTypeNotSupported))
        }

        let request = TransactionsRequest(
            baseUrl: baseUrl,
            walletAddress: walletAddress,
            page: pagination.page,
            limit: pagination.limit,
            apiKey: apiKey ?? "",
            chainShortName: server.okLinkChainShortName,
            protocolType: .erc20,
            headers: Self.allHTTPHeaderFields)

        let decoder = TransactionListDecoder(pagination: pagination, paginationFilter: paginationFilter)
        let analytics = analytics
        let domainName = baseUrl.host!

        return transporter.dataTaskPublisher(request)
            .handleEvents(receiveOutput: { [server] in Self.log(response: $0, server: server, analytics: analytics, domainName: domainName) })
            .tryMap { try decoder.decode(data: $0.data) }
            .mapError { PromiseError(error: $0) }
            .flatMap { response -> AnyPublisher<TransactionsResponse, PromiseError> in
                let contracts = response.transactions.compactMap { AlphaWallet.Address(uncheckedAgainstNullAddress: $0.tokenContractAddress) }
                return self.fetchMissingOperationData(contracts: Array(Set(contracts)))
                    .setFailureType(to: PromiseError.self)
                    .map { operations -> TransactionsResponse in
                        let transactions = self.map(erc20TokenTransferTransactions: response.transactions, operations: operations)
                        let mergedTransactions = Covalent.ToNativeTransactionMapper.mergeTransactionOperationsIntoSingleTransaction(transactions)
                        return TransactionsResponse(transactions: mergedTransactions, nextPage: response.nextPage)
                    }.eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }

    public func erc721TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                                pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError> {

        guard let pagination = (pagination ?? defaultPagination) as? PageBasedTransactionsPagination else {
            return .fail(PromiseError(error: BlockchainExplorerError.paginationTypeNotSupported))
        }

        let request = TransactionsRequest(
            baseUrl: baseUrl,
            walletAddress: walletAddress,
            page: pagination.page,
            limit: pagination.limit,
            apiKey: apiKey ?? "",
            chainShortName: server.okLinkChainShortName,
            protocolType: .erc721,
            headers: Self.allHTTPHeaderFields)

        let decoder = TransactionListDecoder(pagination: pagination, paginationFilter: paginationFilter)
        let analytics = analytics
        let domainName = baseUrl.host!

        return transporter.dataTaskPublisher(request)
            .handleEvents(receiveOutput: { [server] in Self.log(response: $0, server: server, analytics: analytics, domainName: domainName) })
            .tryMap { try decoder.decode(data: $0.data) }
            .mapError { PromiseError(error: $0) }
            .flatMap { response -> AnyPublisher<TransactionsResponse, PromiseError> in
                let contracts = response.transactions.compactMap { AlphaWallet.Address(uncheckedAgainstNullAddress: $0.tokenContractAddress) }
                return self.fetchMissingOperationData(contracts: Array(Set(contracts)))
                    .setFailureType(to: PromiseError.self)
                    .map { operations -> TransactionsResponse in
                        let transactions = self.map(erc721TokenTransferTransactions: response.transactions, operations: operations)
                        let mergedTransactions = Covalent.ToNativeTransactionMapper.mergeTransactionOperationsIntoSingleTransaction(transactions)
                        return TransactionsResponse(transactions: mergedTransactions, nextPage: response.nextPage)
                    }.eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }

    public func erc1155TokenTransferTransaction(walletAddress: AlphaWallet.Address,
                                                pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError> {

        guard let pagination = (pagination ?? defaultPagination) as? PageBasedTransactionsPagination else {
            return .fail(PromiseError(error: BlockchainExplorerError.paginationTypeNotSupported))
        }

        let request = TransactionsRequest(
            baseUrl: baseUrl,
            walletAddress: walletAddress,
            page: pagination.page,
            limit: pagination.limit,
            apiKey: apiKey ?? "",
            chainShortName: server.okLinkChainShortName,
            protocolType: .erc1155,
            headers: Self.allHTTPHeaderFields)

        let decoder = TransactionListDecoder(pagination: pagination, paginationFilter: paginationFilter)
        let analytics = analytics
        let domainName = baseUrl.host!

        return transporter.dataTaskPublisher(request)
            .handleEvents(receiveOutput: { [server] in Self.log(response: $0, server: server, analytics: analytics, domainName: domainName) })
            .tryMap { try decoder.decode(data: $0.data) }
            .mapError { PromiseError(error: $0) }
            .flatMap { response -> AnyPublisher<TransactionsResponse, PromiseError> in
                let contracts = response.transactions.compactMap { AlphaWallet.Address(uncheckedAgainstNullAddress: $0.tokenContractAddress) }
                return self.fetchMissingOperationData(contracts: Array(Set(contracts)))
                    .setFailureType(to: PromiseError.self)
                    .map { operations -> TransactionsResponse in
                        let transactions = self.map(erc1155TokenTransferTransactions: response.transactions, operations: operations)
                        let mergedTransactions = Covalent.ToNativeTransactionMapper.mergeTransactionOperationsIntoSingleTransaction(transactions)
                        return TransactionsResponse(transactions: transactions, nextPage: response.nextPage)
                    }.eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }

    public func erc20TokenInteractions(walletAddress: AlphaWallet.Address,
                                       pagination: TransactionsPagination?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError> {

        return .fail(PromiseError(error: BlockchainExplorerError.methodNotSupported))
    }

    public func erc721TokenInteractions(walletAddress: AlphaWallet.Address,
                                        pagination: TransactionsPagination?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError> {

        return .fail(PromiseError(error: BlockchainExplorerError.methodNotSupported))
    }

    public func erc1155TokenInteractions(walletAddress: AlphaWallet.Address,
                                         pagination: TransactionsPagination?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError> {

        return .fail(PromiseError(error: BlockchainExplorerError.methodNotSupported))
    }

    private func map(erc20TokenTransferTransactions transactions: [Oklink.Transaction],
                     operations: [AlphaWallet.Address: ContractData]) -> [Transaction] {

        return transactions.compactMap { tx -> Transaction? in
            guard let contract = AlphaWallet.Address(uncheckedAgainstNullAddress: tx.tokenContractAddress) else { return nil }
            let operation = operations[contract]

            let localizedOperation = LocalizedOperation(
                from: tx.from,
                to: tx.to,
                contract: contract,
                type: OperationType.erc20TokenTransfer.rawValue,
                value: String(tx.amount),
                tokenId: "",
                symbol: operation?.symbol ?? tx.transactionSymbol,
                name: operation?.name ?? "",
                decimals: operation?.decimals ?? 18)

            return Transaction(
                id: tx.hash,
                server: server,
                blockNumber: tx.height,
                transactionIndex: 0,
                from: tx.from,
                to: tx.to,
                value: "0",
                gas: "0",
                gasPrice: GasPrice.legacy(gasPrice: .zero),
                gasUsed: "0",
                nonce: "0",
                date: Date(timeIntervalSince1970: tx.transactionTime / 100),
                localizedOperations: [localizedOperation],
                state: TransactionState(state: tx.state),
                isErc20Interaction: true)
        }
    }

    private func map(erc721TokenTransferTransactions transactions: [Oklink.Transaction],
                     operations: [AlphaWallet.Address: ContractData]) -> [Transaction] {

        return transactions.compactMap { tx -> Transaction? in
            guard let contract = AlphaWallet.Address(uncheckedAgainstNullAddress: tx.tokenContractAddress) else { return nil }
            let operation = operations[contract]

            let localizedOperation = LocalizedOperation(
                from: tx.from,
                to: tx.to,
                contract: contract,
                type: OperationType.erc721TokenTransfer.rawValue,
                value: String(tx.amount),
                tokenId: tx.tokenId,
                symbol: operation?.symbol ?? tx.transactionSymbol,
                name: operation?.name ?? "",
                decimals: operation?.decimals ?? 0)

            return Transaction(
                id: tx.hash,
                server: server,
                blockNumber: tx.height,
                transactionIndex: 0,
                from: tx.from,
                to: tx.to,
                value: "0",
                gas: "0",
                gasPrice: GasPrice.legacy(gasPrice: .zero),
                gasUsed: "0",
                nonce: "0",
                date: Date(timeIntervalSince1970: tx.transactionTime / 100),
                localizedOperations: [localizedOperation],
                state: TransactionState(state: tx.state),
                isErc20Interaction: true)
        }
    }

    private func map(erc1155TokenTransferTransactions transactions: [Oklink.Transaction],
                     operations: [AlphaWallet.Address: ContractData]) -> [Transaction] {

        return transactions.compactMap { tx -> Transaction? in
            guard let contract = AlphaWallet.Address(uncheckedAgainstNullAddress: tx.tokenContractAddress) else { return nil }
            let operation = operations[contract]

            let localizedOperation = LocalizedOperation(
                from: tx.from,
                to: tx.to,
                contract: contract,
                type: OperationType.erc1155TokenTransfer.rawValue,
                value: String(tx.amount),
                tokenId: tx.tokenId,
                //TODO: tokenValue: tx.tokenValue,
                symbol: operation?.symbol ?? tx.transactionSymbol,
                name: operation?.name ?? "",
                decimals: operation?.decimals ?? 0)

            return Transaction(
                id: tx.hash,
                server: server,
                blockNumber: tx.height,
                transactionIndex: 0,
                from: tx.from,
                to: tx.to,
                value: "0",
                gas: "0",
                gasPrice: GasPrice.legacy(gasPrice: .zero),
                gasUsed: "0",
                nonce: "0",
                date: Date(timeIntervalSince1970: tx.transactionTime / 100),
                localizedOperations: [localizedOperation],
                state: TransactionState(state: tx.state),
                isErc20Interaction: true)
        }
    }

    private typealias ContractData = (name: String, decimals: Int, symbol: String)
    private func fetchMissingOperationData(contracts: [AlphaWallet.Address]) -> AnyPublisher<[AlphaWallet.Address: ContractData], Never> {
        let publishers = contracts.map { contract in
            let p1 = ercTokenProvider.getContractName(for: contract)
            let p2 = ercTokenProvider.getDecimals(for: contract)
            let p3 = ercTokenProvider.getContractSymbol(for: contract)

            return Publishers.CombineLatest3(p1, p2, p3)
                .map { (contract: contract, name: $0.0, decimals: $0.1, symbol: $0.2) }
                .map { Optional($0) }
                .replaceError(with: nil)
                .eraseToAnyPublisher()
        }

        return Publishers.MergeMany(publishers)
            .collect()
            .map { $0.compactMap { $0 } }
            .map { data -> [AlphaWallet.Address: ContractData] in
                var values: [AlphaWallet.Address: ContractData] = [:]
                for each in data { values[each.contract] = (name: each.name, decimals: each.decimals, symbol: each.symbol) }

                return values
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
// swiftlint:enable type_body_length

fileprivate extension TransactionState {
    init(state: Oklink.TransactionState) {
        switch state {
        case .fail:
            self = .error
        case .pending:
            self = .pending
        case .success:
            self = .completed
        }
    }
}

extension OklinkBlockchainExplorer {

    struct Response<T> {
        let transactions: [T]
        let nextPage: PageBasedTransactionsPagination

        init(transactions: [T], nextPage: PageBasedTransactionsPagination) {
            self.transactions = transactions
            self.nextPage = nextPage
        }
    }

    struct TransactionListDecoder {
        let pagination: PageBasedTransactionsPagination
        let paginationFilter: TransactionPageBasedPaginationFilter

        func decode(data: Data) throws -> Response<Oklink.Transaction> {
            guard
                let json = try? JSON(data: data),
                let response = Oklink.TransactionListResponse<Oklink.Transaction>(json: json)
            else { throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "")) }

            guard let transactionsData = response.data.first else { return .init(transactions: [], nextPage: pagination) }

            let data = paginationFilter.process(transactions: transactionsData.transactionList, pagination: pagination)

            return .init(transactions: data.transactions, nextPage: data.nexPage)
        }
    }

    struct NormalTransactionListDecoder {
        let pagination: PageBasedTransactionsPagination
        let paginationFilter: TransactionPageBasedPaginationFilter

        func decode(data: Data) throws -> Response<NormalTransaction> {
            guard
                let json = try? JSON(data: data),
                let response = Oklink.TransactionListResponse<Oklink.Transaction>(json: json)
            else { throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "")) }

            guard let transactionsData = response.data.first else { return .init(transactions: [], nextPage: pagination) }

            let transactions = transactionsData.transactionList.map { NormalTransaction(okLinkTransaction: $0) }
            let data = paginationFilter.process(transactions: transactions, pagination: pagination)

            return .init(transactions: data.transactions, nextPage: data.nexPage)
        }
    }

    struct TransactionsRequest: URLRequestConvertible {
        let baseUrl: URL
        let walletAddress: AlphaWallet.Address
        let page: Int
        let limit: Int
        let apiKey: String
        let chainShortName: String
        let protocolType: Oklink.ProtocolType
        let headers: HTTPHeaders

        func asURLRequest() throws -> URLRequest {
            guard var components: URLComponents = .init(url: baseUrl, resolvingAgainstBaseURL: false) else {
                throw URLError(.badURL)
            }
            components.path = "/api/v5/explorer/address/transaction-list"

            let url = try components.asURL()
            var headers = headers
            headers.add(name: "Ok-Access-Key", value: apiKey)
            let request = try URLRequest(url: url, method: .get, headers: headers)

            return try URLEncoding().encode(request, with: [
                "address": walletAddress.eip55String,
                "protocolType": protocolType.rawValue,
                "chainShortName": chainShortName,
                "page": "\(page)",
                "limit": "\(limit)"
            ])
        }
    }
}

private extension RPCServer {
    var okLinkChainShortName: String {
        switch self {
        case .xDai: return ""
        case .binance_smart_chain: return ""
        case .binance_smart_chain_testnet: return ""
        case .heco: return ""
        case .heco_testnet: return ""
        case .main, .callisto, .classic, .goerli: return ""
        case .fantom: return ""
        case .fantom_testnet: return ""
        case .avalanche: return ""
        case .avalanche_testnet: return ""
        case .polygon: return ""
        case .mumbai_testnet: return ""
        case .optimistic: return ""
        case .cronosMainnet: return ""
        case .cronosTestnet: return ""
        case .custom(let custom): return ""
        case .arbitrum: return ""
        case .palm: return ""
        case .palmTestnet: return ""
        case .klaytnCypress: return ""
        case .klaytnBaobabTestnet: return ""
        case .ioTeX: return ""
        case .ioTeXTestnet: return ""
        case .optimismGoerli: return ""
        case .arbitrumGoerli: return ""
        case .okx: return "OKC"
        case .sepolia: return ""
        }
    }
}
