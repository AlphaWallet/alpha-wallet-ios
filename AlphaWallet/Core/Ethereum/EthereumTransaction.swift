// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import APIKit
import JSONRPCKit
import PromiseKit

enum EthereumTransaction {
    typealias Id = String

    struct NotCompletedYet: Error {}

    static func isCompleted(transactionId: Id, server: RPCServer) -> Promise<Bool> {
        let request = GetTransactionRequest(hash: transactionId)
        return firstly {
            Session.send(EtherServiceRequest(server: server, batch: BatchFactory().create(request)))
        }.map { pendingTransaction in
            NSLog("xxx get block number for approval transaction: \(pendingTransaction.blockNumber)")
            if let blockNumber = Int(pendingTransaction.blockNumber), blockNumber > 0 {
                return true
            } else {
                return false
            }
        }
    }

    //TODO use pub-sub API or similar, instead
    static func waitTillCompleted(transactionId: Id, server: RPCServer, timesToRepeat: Int = 50) -> Promise<Void> {
        NSLog("xxx getTransactionCompletionState() with timesToRepeat \(timesToRepeat)…")
        return attempt(maximumRetryCount: timesToRepeat, delayBeforeRetry: .seconds(10), delayUpperRangeValueFrom0To: 20) {
            firstly {
                EthereumTransaction.isCompleted(transactionId: transactionId, server: server)
            }.map { isCompleted in
                if isCompleted {
                    NSLog("xxx getTransactionCompletionState() approval is completed")
                    return ()
                } else {
                    NSLog("xxx getTransactionCompletionState() approval not completed yet. Maybe retrying or stop…")
                    throw NotCompletedYet()
                }
            }
        }
    }
}