//
//  CovalentNetworkProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2022.
//

import SwiftyJSON
import Combine
import AlphaWalletCore

public class CovalentApiNetworking: ApiNetworking {
    private let server: RPCServer
    private let baseUrl: URL = URL(string: "https://api.covalenthq.com")!
    private let apiKey: String?
    private let transporter: ApiTransporter
    private let paginationFilter = TransactionPaginationFilter()

    public init(server: RPCServer,
                apiKey: String?,
                transporter: ApiTransporter) {

        self.server = server
        self.apiKey = apiKey
        self.transporter = transporter
    }

    public func normalTransactions(walletAddress: AlphaWallet.Address,
                                   pagination: TransactionsPagination) -> AnyPublisher<TransactionsResponse<TransactionInstance>, PromiseError> {

        let request = TransactionsRequest(
            baseUrl: baseUrl,
            walletAddress: walletAddress,
            server: server,
            page: pagination.page,
            pageSize: pagination.limit,
            apiKey: apiKey ?? "",
            blockSignedAtAsc: true)

        return transporter.dataTaskPublisher(request)
            .handleEvents(receiveOutput: { EtherscanCompatibleApiNetworking.log(response: $0) })
            .tryMap { [server, paginationFilter] response -> TransactionsResponse<TransactionInstance> in
                guard let json = try? JSON(data: response.data) else { throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "")) }

                let response = try Covalent.TransactionsResponse(json: json)
                let data = paginationFilter.process(transactions: response.data.transactions, pagination: pagination)
                let transactions = Covalent.ToNativeTransactionMapper.mapCovalentToNativeTransaction(transactions: data.transactions, server: server)
                let mergedTransactions = Covalent.ToNativeTransactionMapper.mergeTransactionOperationsIntoSingleTransaction(transactions)

                return TransactionsResponse<TransactionInstance>(transactions: mergedTransactions, pagination: data.pagination)
            }.mapError { PromiseError(error: $0) }
            .eraseToAnyPublisher()
    }

    public func erc20TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                               pagination: TransactionsPagination) -> AnyPublisher<TransactionsResponse<TransactionInstance>, PromiseError> {
        return .empty()
    }

    public func erc721TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                                pagination: TransactionsPagination) -> AnyPublisher<TransactionsResponse<TransactionInstance>, PromiseError> {
        return .empty()
    }

    public func erc1155TokenTransferTransaction(walletAddress: AlphaWallet.Address,
                                                pagination: TransactionsPagination) -> AnyPublisher<TransactionsResponse<TransactionInstance>, PromiseError> {
        return .empty()
    }

    public func erc20TokenInteractions(walletAddress: AlphaWallet.Address,
                                       startBlock: Int?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError> {
        return .empty()
    }

    public func erc721TokenInteractions(walletAddress: AlphaWallet.Address,
                                        startBlock: Int?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError> {
        return .empty()
    }

    public func erc1155TokenInteractions(walletAddress: AlphaWallet.Address,
                                         startBlock: Int?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError> {
        return .empty()
    }
    
    public func erc20TokenTransferTransactions(startBlock: Int?) -> AnyPublisher<([TransactionInstance], Int), PromiseError> {
        return .empty()
    }

    public func erc721TokenTransferTransactions(startBlock: Int?) -> AnyPublisher<([TransactionInstance], Int), PromiseError> {
        return .empty()
    }

    public func normalTransactions(startBlock: Int, endBlock: Int, sortOrder: GetTransactions.SortOrder) -> AnyPublisher<[TransactionInstance], PromiseError> {
        return .empty()
    }

    public func erc1155TokenTransferTransactions(startBlock: Int?) -> AnyPublisher<([TransactionInstance], Int), AlphaWalletCore.PromiseError> {
        return .empty()
    }

}

extension CovalentApiNetworking {

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
