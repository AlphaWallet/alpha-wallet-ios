//
//  WaitTillTransactionCompleted.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.08.2022.
//

import Foundation
import PromiseKit
import AlphaWalletCore

//TODO: improve waiting for tx completion
public final class WaitTillTransactionCompleted {
    private let server: RPCServer
    private let analytics: AnalyticsLogger
    private lazy var provider = GetPendingTransaction(server: server, analytics: analytics)

    public init(server: RPCServer, analytics: AnalyticsLogger) {
        self.server = server
        self.analytics = analytics
    }

    public func waitTillCompleted(hash: EthereumTransaction.Hash, timesToRepeat: Int = 50) -> Promise<Void> {
        return attempt(maximumRetryCount: timesToRepeat, delayBeforeRetry: .seconds(10), delayUpperRangeValueFrom0To: 20) { [provider] in
            return firstly {
                provider.getPendingTransaction(hash: hash)
            }.map { pendingTransaction in
                if let pendingTransaction = pendingTransaction, let blockNumber = Int(pendingTransaction.blockNumber), blockNumber > 0 {
                    return ()
                } else {
                    throw EthereumTransaction.NotCompletedYet()
                }
            }
        }
    }
}
