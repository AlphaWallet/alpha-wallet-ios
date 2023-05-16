//
//  TransactionPageBasedPaginationFilter.swift
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

//TODO: specify that its only for page based
struct TransactionPageBasedPaginationFilter {

    func process<T: TransactionPaginationSupportable>(transactions: [T], pagination: PageBasedTransactionsPagination) -> (transactions: [T], nexPage: PageBasedTransactionsPagination) {
        let nexPage: PageBasedTransactionsPagination
        let txs: [T]
        
        if transactions.count == pagination.limit {
            txs = transactions.filter { tx in !pagination.lastFetched.contains(where: { $0 == tx.hash }) }

            nexPage = PageBasedTransactionsPagination(
                page: pagination.page + 1,
                lastFetched: [],
                limit: pagination.limit)
        } else {
            if pagination.lastFetched.isEmpty {
                txs = transactions

                nexPage = PageBasedTransactionsPagination(
                    page: pagination.page,
                    lastFetched: txs.map { $0.hash },
                    limit: pagination.limit)
            } else {
                txs = transactions.filter { tx in !pagination.lastFetched.contains(where: { $0 == tx.hash }) }
                let lastFetched = Array(Set(pagination.lastFetched + txs.map { $0.hash }))

                if lastFetched.count >= pagination.limit {
                    nexPage = PageBasedTransactionsPagination(
                        page: pagination.page + 1,
                        lastFetched: [],
                        limit: pagination.limit)
                } else {
                    nexPage = PageBasedTransactionsPagination(
                        page: pagination.page,
                        lastFetched: lastFetched,
                        limit: pagination.limit)
                }
            }
        }
        
        return (transactions: txs, nexPage: nexPage)
    }
}

public struct PageBasedTransactionsPagination: Codable, TransactionsPagination {
    public let page: Int
    public let lastFetched: [String]
    public let limit: Int

    public init(page: Int, lastFetched: [String], limit: Int) {
        self.page = page
        self.lastFetched = lastFetched
        self.limit = limit
    }
}
