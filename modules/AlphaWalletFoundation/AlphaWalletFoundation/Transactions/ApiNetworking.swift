//
//  ApiNetworking.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 07.03.2023.
//

import Foundation
import Combine
import AlphaWalletCore

public struct TransactionsResponse<T> {
    public let transactions: [T]
    public let pagination: TransactionsPagination

    public init(transactions: [T], pagination: TransactionsPagination) {
        self.transactions = transactions
        self.pagination = pagination
    }
}

public protocol ApiNetworking {
    func normalTransactions(walletAddress: AlphaWallet.Address,
                            pagination: TransactionsPagination,
                            sortOrder: GetTransactions.SortOrder?) -> AnyPublisher<TransactionsResponse<TransactionInstance>, PromiseError>

    func erc20TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                        pagination: TransactionsPagination,
                                        sortOrder: GetTransactions.SortOrder?) -> AnyPublisher<TransactionsResponse<TransactionInstance>, PromiseError>

    func erc721TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                         pagination: TransactionsPagination,
                                         sortOrder: GetTransactions.SortOrder?) -> AnyPublisher<TransactionsResponse<TransactionInstance>, PromiseError>

    func erc1155TokenTransferTransaction(walletAddress: AlphaWallet.Address,
                                         pagination: TransactionsPagination,
                                         sortOrder: GetTransactions.SortOrder?) -> AnyPublisher<TransactionsResponse<TransactionInstance>, PromiseError>
}
