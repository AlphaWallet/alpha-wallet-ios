//
//  FallbackApiNetworking.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 09.05.2023.
//

import Foundation
import SwiftyJSON
import Combine
import AlphaWalletCore
import BigInt
import AlphaWalletLogger
import Alamofire

class FallbackApiNetworking: ApiNetworking {

    func gasPriceEstimates() -> AnyPublisher<LegacyGasEstimates, PromiseError> {
        return .fail(PromiseError(error: ApiNetworkingError.methodNotSupported))
    }

    func normalTransactions(walletAddress: AlphaWallet.Address,
                            sortOrder: GetTransactions.SortOrder,
                            pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError> {
        return .empty()
    }

    func erc20TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                        pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError> {
        return .empty()
    }

    func erc721TokenTransferTransactions(walletAddress: AlphaWallet.Address,
                                         pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError> {
        return .empty()
    }

    func erc1155TokenTransferTransaction(walletAddress: AlphaWallet.Address,
                                         pagination: TransactionsPagination?) -> AnyPublisher<TransactionsResponse, PromiseError> {
        return .empty()
    }

    func erc20TokenInteractions(walletAddress: AlphaWallet.Address,
                                pagination: TransactionsPagination?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError> {
        return .empty()
    }

    func erc721TokenInteractions(walletAddress: AlphaWallet.Address,
                                 pagination: TransactionsPagination?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError> {
        return .empty()
    }

    func erc1155TokenInteractions(walletAddress: AlphaWallet.Address,
                                  pagination: TransactionsPagination?) -> AnyPublisher<UniqueNonEmptyContracts, PromiseError> {
        return .empty()
    }
}
