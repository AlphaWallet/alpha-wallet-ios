//
//  ApiNetworking.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 07.03.2023.
//

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletLogger
import SwiftyJSON

public struct TransactionsResponse {
    public let transactions: [Transaction]
    public let pagination: TransactionsPagination

    public init(transactions: [Transaction], pagination: TransactionsPagination) {
        self.transactions = transactions
        self.pagination = pagination
    }
}

public enum ApiNetworkingError: Error {
    case methodNotSupported
}

public protocol ApiNetworking {
    func normalTransactions(walletAddress: AlphaWallet.Address,
                            pagination: TransactionsPagination) -> AnyPublisher<TransactionsResponse, PromiseError>

    func erc20TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                        pagination: TransactionsPagination) -> AnyPublisher<TransactionsResponse, PromiseError>

    func erc721TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                         pagination: TransactionsPagination) -> AnyPublisher<TransactionsResponse, PromiseError>

    func erc1155TokenTransferTransaction(walletAddress: AlphaWallet.Address,
                                         pagination: TransactionsPagination) -> AnyPublisher<TransactionsResponse, PromiseError>

    func erc20TokenInteractions(walletAddress: AlphaWallet.Address,
                                startBlock: Int?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError>

    func erc721TokenInteractions(walletAddress: AlphaWallet.Address,
                                 startBlock: Int?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError>

    func erc1155TokenInteractions(walletAddress: AlphaWallet.Address,
                                  startBlock: Int?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError>

    func normalTransactions(walletAddress: AlphaWallet.Address,
                            startBlock: Int,
                            endBlock: Int,
                            sortOrder: GetTransactions.SortOrder) -> AnyPublisher<[Transaction], PromiseError>

    func erc20TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                        startBlock: Int?) -> AnyPublisher<([Transaction], Int), PromiseError>

    func erc721TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                         startBlock: Int?) -> AnyPublisher<([Transaction], Int), PromiseError>

    func erc1155TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                          startBlock: Int?) -> AnyPublisher<([Transaction], Int), PromiseError>

    func gasPriceEstimates() -> AnyPublisher<LegacyGasEstimates, PromiseError>
}

