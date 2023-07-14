// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletLogger
import SwiftyJSON

public protocol TransactionsPagination: Codable { }

public struct TransactionsResponse {
    let transactions: [Transaction]
    let nextPage: TransactionsPagination?
}

struct BlockBasedPagination: TransactionsPagination {
    let startBlock: Int?
    let endBlock: Int?
}

public enum BlockchainExplorerError: Error {
    case paginationTypeNotSupported
    case methodNotSupported
}

//TODO: replace publisher with async await later
public protocol BlockchainExplorer {
    func normalTransactions(walletAddress: AlphaWallet.Address,
                            sortOrder: GetTransactions.SortOrder,
                            pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError>

    func erc20TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                        pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError>

    func erc721TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                         pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError>

    func erc1155TokenTransferTransaction(walletAddress: AlphaWallet.Address,
                                         pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError>

    func erc20TokenInteractions(walletAddress: AlphaWallet.Address,
                                pagination: TransactionsPagination?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError>

    func erc721TokenInteractions(walletAddress: AlphaWallet.Address,
                                 pagination: TransactionsPagination?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError>

    func erc1155TokenInteractions(walletAddress: AlphaWallet.Address,
                                  pagination: TransactionsPagination?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError>

    func gasPriceEstimates() -> AnyPublisher<LegacyGasEstimates, PromiseError>
}

