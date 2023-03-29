//
//  PaginationStorage.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 12.05.2023.
//

import Foundation

protocol PaginationStorage {
    func pagination(key: String) -> TransactionsPagination?
    func set(pagination: TransactionsPagination?, key: String)
}

extension WalletConfig: PaginationStorage {

    func pagination(key: String) -> TransactionsPagination? {
        return decodeBlockBasedPagination(key: key) ?? decodePageBasedPagination(key: key)
    }

    func set(pagination: TransactionsPagination?, key: String) {
        if let pagination = pagination as? BlockBasedPagination {
            encodeBlockBasedPagination(key: key, pagination: pagination)
        } else if let pagination = pagination as? PageBasedTransactionsPagination {
            encodePageBasedPagination(key: key, pagination: pagination)
        } else {
            defaults.set(nil, forKey: key)
        }
    }

    private func decodeBlockBasedPagination(key: String) -> BlockBasedPagination? {
        defaults.data(forKey: key + "blockBased").flatMap {
            try? JSONDecoder().decode(BlockBasedPagination.self, from: $0)
        }
    }

    private func decodePageBasedPagination(key: String) -> PageBasedTransactionsPagination? {
        defaults.data(forKey: key + "pageBased").flatMap {
            try? JSONDecoder().decode(PageBasedTransactionsPagination.self, from: $0)
        }
    }

    private func encodeBlockBasedPagination(key: String, pagination: BlockBasedPagination) {
        let value = try? JSONEncoder().encode(pagination)
        defaults.set(value, forKey: key + "blockBased")
    }

    private func encodePageBasedPagination(key: String, pagination: PageBasedTransactionsPagination) {
        let value = try? JSONEncoder().encode(pagination)
        defaults.set(value, forKey: key + "pageBased")
    }

}
