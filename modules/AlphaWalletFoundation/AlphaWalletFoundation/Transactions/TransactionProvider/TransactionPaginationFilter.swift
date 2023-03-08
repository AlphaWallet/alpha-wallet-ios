//
//  TransactionPaginationFilter.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 08.03.2023.
//

import Foundation

protocol TransactionPaginationSupportable {
    var hash: String { get }
}

extension NormalTransaction: TransactionPaginationSupportable {}
extension Erc20TokenTransferTransaction: TransactionPaginationSupportable {}
extension Erc721TokenTransferTransaction: TransactionPaginationSupportable {}
extension Erc1155TokenTransferTransaction: TransactionPaginationSupportable {}

extension Covalent.Transaction: TransactionPaginationSupportable {
    var hash: String { txHash }
}

extension Oklink.Transaction: TransactionPaginationSupportable {
    var hash: String { txId }
}

struct TransactionPaginationFilter {

    func process<T: TransactionPaginationSupportable>(transactions: [T], pagination: TransactionsPagination) -> (transactions: [T], pagination: TransactionsPagination) {
        let newPagination: TransactionsPagination
        let txs: [T]
        
        if transactions.count == pagination.limit {
            txs = transactions.filter { tx in !pagination.lastFetched.contains(where: { $0 == tx.hash }) }

            newPagination = TransactionsPagination(
                page: pagination.page + 1,
                lastFetched: [],
                limit: pagination.limit)
        } else {
            if pagination.lastFetched.isEmpty {
                txs = transactions

                newPagination = TransactionsPagination(
                    page: pagination.page,
                    lastFetched: txs.map { $0.hash },
                    limit: pagination.limit)
            } else {
                txs = transactions.filter { tx in !pagination.lastFetched.contains(where: { $0 == tx.hash }) }
                let lastFetched = Array(Set(pagination.lastFetched + txs.map { $0.hash }))

                if lastFetched.count >= pagination.limit {
                    newPagination = TransactionsPagination(
                        page: pagination.page + 1,
                        lastFetched: [],
                        limit: pagination.limit)
                } else {
                    newPagination = TransactionsPagination(
                        page: pagination.page,
                        lastFetched: lastFetched,
                        limit: pagination.limit)
                }
            }
        }
        
        return (transactions: txs, pagination: newPagination)
    }
}

public struct TransactionsPagination: Codable {
    public let page: Int
    public let lastFetched: [String]
    public let limit: Int

    public init(page: Int, lastFetched: [String], limit: Int) {
        self.page = page
        self.lastFetched = lastFetched
        self.limit = limit
    }

    public func next(initial: Bool = false) -> TransactionsPagination {
        if lastFetched.isEmpty {
            return TransactionsPagination(page: initial ? page : page + 1, lastFetched: [], limit: limit)
        } else {
            return TransactionsPagination(page: page, lastFetched: lastFetched, limit: limit)
        }
    }
}
