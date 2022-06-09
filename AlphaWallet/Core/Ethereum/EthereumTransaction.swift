// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import APIKit
import JSONRPCKit
import PromiseKit
import AlphaWalletCore

enum EthereumTransaction {
    typealias Id = String

    struct NotCompletedYet: Error {}

    static func isCompleted(transactionId: Id, server: RPCServer) -> Promise<Bool> {
        let request = GetTransactionRequest(hash: transactionId)
        return firstly {
            Session.send(EtherServiceRequest(server: server, batch: BatchFactory().create(request)))
        }.map { pendingTransaction in
            if let blockNumber = Int(pendingTransaction.blockNumber), blockNumber > 0 {
                return true
            } else {
                return false
            }
        }
    }

    //TODO use pub-sub API or similar, instead
    static func waitTillCompleted(transactionId: Id, server: RPCServer, timesToRepeat: Int = 50) -> Promise<Void> {
        return attempt(maximumRetryCount: timesToRepeat, delayBeforeRetry: .seconds(10), delayUpperRangeValueFrom0To: 20) {
            firstly {
                EthereumTransaction.isCompleted(transactionId: transactionId, server: server)
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
