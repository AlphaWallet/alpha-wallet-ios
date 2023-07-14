// Copyright © 2023 Stormbird PTE. LTD.

import Combine
import AlphaWalletCore
import AlphaWalletLogger
import SwiftyJSON

public class CovalentBlockchainExplorer: BlockchainExplorer {
    private let server: RPCServer
    private let baseUrl: URL = URL(string: "https://api.covalenthq.com")!
    private let apiKey: String?
    private let transporter: ApiTransporter
    private let paginationFilter = TransactionPageBasedPaginationFilter()
    private let defaultPagination = PageBasedTransactionsPagination(page: 0, lastFetched: [], limit: 500)
    private let analytics: AnalyticsLogger

    public init(server: RPCServer, apiKey: String?, transporter: ApiTransporter, analytics: AnalyticsLogger) {
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
            server: server,
            page: pagination.page,
            pageSize: pagination.limit,
            apiKey: apiKey ?? "",
            blockSignedAtAsc: sortOrder == .asc)
        let analytics = analytics
        let domainName = baseUrl.host!

        return transporter.dataTaskPublisher(request)
            .handleEvents(receiveOutput: { [server] in Self.log(response: $0, server: server, analytics: analytics, domainName: domainName) })
            .tryMap { [server, paginationFilter] response -> TransactionsResponse in
                guard let json = try? JSON(data: response.data) else { throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "")) }

                let response = try Covalent.TransactionsResponse(json: json)
                let data = paginationFilter.process(transactions: response.data.transactions, pagination: pagination)
                let transactions = Covalent.ToNativeTransactionMapper.mapCovalentToNativeTransaction(transactions: data.transactions, server: server)
                let mergedTransactions = Covalent.ToNativeTransactionMapper.mergeTransactionOperationsIntoSingleTransaction(transactions)

                return TransactionsResponse(transactions: mergedTransactions, nextPage: data.nexPage)
            }.mapError { PromiseError(error: $0) }
            .eraseToAnyPublisher()
    }

    public func erc20TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                               pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError> {

        return .fail(PromiseError(error: BlockchainExplorerError.methodNotSupported))
    }

    public func erc721TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                                pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError> {

        return .fail(PromiseError(error: BlockchainExplorerError.methodNotSupported))
    }

    public func erc1155TokenTransferTransaction(walletAddress: AlphaWallet.Address,
                                                pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError> {

        return .fail(PromiseError(error: BlockchainExplorerError.methodNotSupported))
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

extension CovalentBlockchainExplorer {

    struct TransactionsRequest: URLRequestConvertible {
        let baseUrl: URL
        let walletAddress: AlphaWallet.Address
        let server: RPCServer
        let page: Int?
        let pageSize: Int
        let apiKey: String
        let blockSignedAtAsc: Bool

        func asURLRequest() throws -> URLRequest {
            guard var components: URLComponents = .init(url: baseUrl, resolvingAgainstBaseURL: false) else {
                throw URLError(.badURL)
            }

            components.path = "/v1/\(server.chainID)/address/\(walletAddress)/transactions_v2/"

            let url = try components.asURL()
            let request = try URLRequest(url: url, method: .get)

            return try URLEncoding().encode(request, with: [
                "key": apiKey,
                "block-signed-at-asc": "\(blockSignedAtAsc)",
                "page-number": "\(page ?? 0)",
                "page-size": "\(pageSize)"
            ])
        }
    }
}
