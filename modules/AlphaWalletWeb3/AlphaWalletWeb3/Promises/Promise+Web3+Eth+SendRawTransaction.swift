//
//  Promise+Web3+Eth+SendRawTransaction.swift
//  web3swift-iOS
//
//  Created by Alexander Vlasov on 18.06.2018.
//  Copyright © 2018 Bankex Foundation. All rights reserved.
//

import Foundation
import PromiseKit

extension Web3.Eth {
    func sendRawTransactionPromise(_ transaction: Data) -> Promise<TransactionSendingResult> {
        guard let deserializedTX = Transaction.fromRaw(transaction) else {
            let promise = Promise<TransactionSendingResult>.pending()
            promise.resolver.reject(Web3Error.inputError("Serialized TX is invalid"))
            return promise.promise
        }
        return sendRawTransactionPromise(deserializedTX)
    }

    func sendRawTransactionPromise(_ transaction: Transaction) -> Promise<TransactionSendingResult> {
        do {
            guard let request = Transaction.createRawTransaction(transaction: transaction) else {
                throw Web3Error.inputError("Transaction is invalid")
            }
            let rp = web3.dispatch(request)
            return rp.map(on: web3.queue) { response in
                guard let value: String = response.getValue() else {
                    if response.error != nil {
                        throw Web3Error.nodeError(response.error!.message)
                    }
                    throw Web3Error.nodeError("Invalid value from Ethereum node")
                }

                return TransactionSendingResult(transaction: transaction, hash: value)
            }
        } catch {
            let returnPromise = Promise<TransactionSendingResult>.pending()
            web3.queue.async {
                returnPromise.resolver.reject(error)
            }
            return returnPromise.promise
        }
    }
}
