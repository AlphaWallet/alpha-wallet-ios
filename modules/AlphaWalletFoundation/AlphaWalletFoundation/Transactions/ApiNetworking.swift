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
                            pagination: TransactionsPagination) -> AnyPublisher<TransactionsResponse<TransactionInstance>, PromiseError>

    func erc20TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                        pagination: TransactionsPagination) -> AnyPublisher<TransactionsResponse<TransactionInstance>, PromiseError>

    func erc721TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                         pagination: TransactionsPagination) -> AnyPublisher<TransactionsResponse<TransactionInstance>, PromiseError>

    func erc1155TokenTransferTransaction(walletAddress: AlphaWallet.Address,
                                         pagination: TransactionsPagination) -> AnyPublisher<TransactionsResponse<TransactionInstance>, PromiseError>

    func erc20TokenInteractions(walletAddress: AlphaWallet.Address,
                                startBlock: Int?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError>

    func erc721TokenInteractions(walletAddress: AlphaWallet.Address,
                                 startBlock: Int?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError>

    func erc1155TokenInteractions(walletAddress: AlphaWallet.Address,
                                  startBlock: Int?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError>

    func normalTransactions(startBlock: Int,
                            endBlock: Int,
                            sortOrder: GetTransactions.SortOrder) -> AnyPublisher<[TransactionInstance], PromiseError>

    func erc20TokenTransferTransactions(startBlock: Int?) -> AnyPublisher<([TransactionInstance], Int), PromiseError>

    func erc721TokenTransferTransactions(startBlock: Int?) -> AnyPublisher<([TransactionInstance], Int), PromiseError>

    func erc1155TokenTransferTransactions(startBlock: Int?) -> AnyPublisher<([TransactionInstance], Int), PromiseError>
}

