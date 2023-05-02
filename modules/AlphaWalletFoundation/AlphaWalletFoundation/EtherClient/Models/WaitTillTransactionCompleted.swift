//
//  WaitTillTransactionCompleted.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.08.2022.
//

import Foundation
import AlphaWalletCore
import Combine

public final class WaitTillTransactionCompleted {
    
    enum TransactionError: Error {
        case `internal`(Error)
        case timeout
        case notInState(TransactionState)
    }

    private let server: RPCServer
    private let transactionDataStore: TransactionDataStore

    public init(transactionDataStore: TransactionDataStore, server: RPCServer) {
        self.transactionDataStore = transactionDataStore
        self.server = server
    }

    /// Return transaction when it reaches state
    /// - state - transactions state required
    /// - hash - transaction hash to look for trsnsaction
    /// - timeout - waiting timeout
    func transaction(hash: String, for state: TransactionState, timeout: Int) -> AnyPublisher<Transaction, TransactionError> {
        transactionDataStore
            .transactionPublisher(for: hash, server: server)
            .mapError { TransactionError.internal($0) }
            .map { tx -> Result<Transaction, TransactionError> in
                if let tx = tx {
                    if tx.state == state {
                        return .success(tx)
                    } else {
                        return .failure(TransactionError.notInState(state))
                    }
                } else {
                    return .failure(TransactionError.internal(DataStoreError.objectNotFound))
                }
            }.compactMap { result -> Transaction? in
                guard case .success(let tx) = result else { return nil }
                return tx
            }.timeout(.seconds(timeout), scheduler: DispatchQueue.main, options: nil) { return TransactionError.timeout }
            .receive(on: DispatchQueue.main)
            .first()
            .eraseToAnyPublisher()
    }
}
