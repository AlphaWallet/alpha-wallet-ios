// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation
import PromiseKit

public class SendTransaction {
    private let keystore: Keystore
    private let session: WalletSession
    private let confirmType: ConfirmType
    private let prompt: String

    public init(session: WalletSession,
                keystore: Keystore,
                confirmType: ConfirmType,
                prompt: String) {

        self.prompt = prompt
        self.session = session
        self.keystore = keystore
        self.confirmType = confirmType
    }

    public func sendPromise(rawTransaction: String) -> Promise<ConfirmResult> {
        return firstly {
            session.blockchainProvider.sendPromise(rawTransaction: rawTransaction)
        }.map { transactionID in
            .sentRawTransaction(id: transactionID, original: rawTransaction)
        }
    }

    private func appendNonce(to: UnsignedTransaction, currentNonce: Int) -> UnsignedTransaction {
        return UnsignedTransaction(
            value: to.value,
            account: to.account,
            to: to.to,
            nonce: currentNonce,
            data: to.data,
            gasPrice: to.gasPrice,
            gasLimit: to.gasLimit,
            server: to.server,
            transactionType: to.transactionType)
    }

    public func sendPromise(transaction: UnsignedTransaction) -> Promise<ConfirmResult> {
        if transaction.nonce >= 0 {
            return signAndSend(transaction: transaction)
        } else {
            return firstly {
                resolveNextNonce(for: transaction)
            }.then { transaction -> Promise<ConfirmResult> in
                return self.signAndSend(transaction: transaction)
            }
        }
    }

    private func resolveNextNonce(for transaction: UnsignedTransaction) -> Promise<UnsignedTransaction> {
        session.blockchainProvider
            .nextNoncePromise()
            .map { nonce -> UnsignedTransaction in
                let transaction = self.appendNonce(to: transaction, currentNonce: nonce)
                return transaction
            }
    }

    private func signAndSend(transaction: UnsignedTransaction) -> Promise<ConfirmResult> {
        firstly {
            keystore.signTransactionPromise(transaction, prompt: prompt)
        }.then { data -> Promise<ConfirmResult> in
            switch self.confirmType {
            case .sign:
                return .value(.signedTransaction(data))
            case .signThenSend:
                return self.sendTransactionRequest(transaction: transaction, data: data)
            }
        }
    }

    private func sendTransactionRequest(transaction: UnsignedTransaction, data: Data) -> Promise<ConfirmResult> {
        return firstly {
            session.blockchainProvider.sendPromise(transaction: transaction, data: data)
        }.map { transactionID in
            .sentTransaction(SentTransaction(id: transactionID, original: transaction))
        }
    }
}

extension RPCServer {
    public func rpcUrlAndHeadersWithReplacementSendPrivateTransactionsProviderIfEnabled(config: Config) -> (url: URL, rpcHeaders: [String: String]) {
        if let rpcUrlForSendPrivateTransactionsNetworkProvider = config.sendPrivateTransactionsProvider?.rpcUrl(forServer: self) {
            return (url: rpcUrlForSendPrivateTransactionsNetworkProvider, rpcHeaders: .init())
        } else {
            return (url: rpcURL, rpcHeaders: rpcHeaders)
        }
    }
}

extension Keystore {
    public func signTransactionPromise(_ transaction: UnsignedTransaction, prompt: String) -> Promise<Data> {
        return Promise { seal in
            switch signTransaction(transaction, prompt: prompt) {
            case .success(let data):
                seal.fulfill(data)
            case .failure(let error):
                seal.reject(error)
            }
        }
    }
}
