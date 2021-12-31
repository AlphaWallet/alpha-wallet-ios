// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation
import APIKit
import JSONRPCKit
import PromiseKit
import Result

class SendTransactionCoordinator {
    private let keystore: Keystore
    private let session: WalletSession
    private let confirmType: ConfirmType
    private let config: Config
    private let analyticsCoordinator: AnalyticsCoordinator

    init(
        session: WalletSession,
        keystore: Keystore,
        confirmType: ConfirmType,
        config: Config,
        analyticsCoordinator: AnalyticsCoordinator
    ) {
        self.session = session
        self.keystore = keystore
        self.confirmType = confirmType
        self.config = config
        self.analyticsCoordinator = analyticsCoordinator
    }

    func send(rawTransaction: String) -> Promise<ConfirmResult> {
        let rawRequest = SendRawTransactionRequest(signedTransaction: rawTransaction.add0x)
        let request = EtherServiceRequest(rpcURL: rpcURL, batch: BatchFactory().create(rawRequest))

        return firstly {
            Session.send(request)
        }.recover { error -> Promise<SendRawTransactionRequest.Response> in
            self.logSelectSendError(error)
            throw error
        }.map { transactionID in
            .sentRawTransaction(id: transactionID, original: rawTransaction)
        }.get {
            info("Sent rawTransaction with transactionId: \($0)")
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
            transactionType: to.transactionType
        )
    }

    func send(transaction: UnsignedTransaction) -> Promise<ConfirmResult> {
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
        firstly {
            GetNextNonce(rpcURL: rpcURL, wallet: session.account.address).promise()
        }.map { nonce -> UnsignedTransaction in
            let transaction = self.appendNonce(to: transaction, currentNonce: nonce)
            return transaction
        }
    }

    private func signAndSend(transaction: UnsignedTransaction) -> Promise<ConfirmResult> {
        firstly {
            keystore.signTransactionPromise(transaction)
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
        let rawTransaction = SendRawTransactionRequest(signedTransaction: data.hexEncoded)
        let request = EtherServiceRequest(rpcURL: rpcURL, batch: BatchFactory().create(rawTransaction))

        return firstly {
            Session.send(request)
        }.recover { error -> Promise<SendRawTransactionRequest.Response> in
            self.logSelectSendError(error)
            throw error
        }.map { transactionID in
            .sentTransaction(SentTransaction(id: transactionID, original: transaction))
        }.get {
            info("Sent transaction with transactionId: \($0)")
        }
    }

    private func logSelectSendError(_ error: Error) {
        guard let error = error as? SendTransactionNotRetryableError else { return }
        switch error {
        case .nonceTooLow:
            analyticsCoordinator.log(error: Analytics.Error.sendTransactionNonceTooLow)
        case .insufficientFunds, .gasPriceTooLow, .gasLimitTooLow, .gasLimitTooHigh, .possibleChainIdMismatch, .executionReverted:
            break
        }
    }

    private var rpcURL: URL {
        session.server.rpcUrlWithReplacementSendPrivateTransactionsProviderIfEnabled(config: config)
    }
}

extension RPCServer {
    func rpcUrlWithReplacementSendPrivateTransactionsProviderIfEnabled(config: Config) -> URL {
        if let rpcUrlForSendPrivateTransactionsNetworkProvider = config.sendPrivateTransactionsProvider?.rpcUrl(forServer: self) {
            return rpcUrlForSendPrivateTransactionsNetworkProvider
        } else {
            return rpcURL
        }
    }
}

extension Keystore {
    func signTransactionPromise(_ transaction: UnsignedTransaction) -> Promise<Data> {
        return Promise { seal in
            switch signTransaction(transaction) {
            case .success(let data):
                seal.fulfill(data)
            case .failure(let error):
                seal.reject(error)
            }
        }
    }
}
