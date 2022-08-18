// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import APIKit
import JSONRPCKit
import PromiseKit
import AlphaWalletCore

enum EthereumTransaction {
    typealias Id = String

    struct NotCompletedYet: Error {}

    static func isCompleted(transactionId: Id, server: RPCServer, analytics: AnalyticsLogger) -> Promise<Bool> {
        let request = GetTransactionRequest(hash: transactionId)
        return firstly {
            Session.send(EtherServiceRequest(server: server, batch: BatchFactory().create(request)), server: server, analytics: analytics)
        }.map { pendingTransaction in
            if let pendingTransaction = pendingTransaction, let blockNumber = Int(pendingTransaction.blockNumber), blockNumber > 0 {
                return true
            } else {
                return false
            }
        }
    }

    //TODO use pub-sub API or similar, instead
    static func waitTillCompleted(transactionId: Id, server: RPCServer, analytics: AnalyticsLogger, timesToRepeat: Int = 50) -> Promise<Void> {
        return attempt(maximumRetryCount: timesToRepeat, delayBeforeRetry: .seconds(10), delayUpperRangeValueFrom0To: 20) {
            firstly {
                EthereumTransaction.isCompleted(transactionId: transactionId, server: server, analytics: analytics)
            }.map { isCompleted in
                if isCompleted {
                    return ()
                } else {
                    throw NotCompletedYet()
                }
            }
        }
    }
}
