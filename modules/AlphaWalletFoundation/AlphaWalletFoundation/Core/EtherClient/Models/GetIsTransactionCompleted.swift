//
//  GetIsTransactionCompleted.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.08.2022.
//

import Foundation
import APIKit
import JSONRPCKit
import PromiseKit
import AlphaWalletCore

public final class GetIsTransactionCompleted {
    private let server: RPCServer
    private let analytics: AnalyticsLogger
    private lazy var provider = GetPendingTransaction(server: server, analytics: analytics)

    public init(server: RPCServer, analytics: AnalyticsLogger) {
        self.server = server
        self.analytics = analytics
    }

    public func getTransactionIfCompleted(hash: EthereumTransaction.Hash) -> Promise<PendingTransaction> {
        return firstly {
            provider.getPendingTransaction(hash: hash)
        }.map { pendingTransaction in
            if let pendingTransaction = pendingTransaction, let blockNumber = Int(pendingTransaction.blockNumber), blockNumber > 0 {
                return pendingTransaction
            } else {
                throw EthereumTransaction.NotCompletedYet()
            }
        }
    }
}
