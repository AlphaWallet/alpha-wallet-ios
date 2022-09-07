// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation
import APIKit
import JSONRPCKit
import PromiseKit

public class SendTransaction {
    private let keystore: Keystore
    private let session: WalletSession
    private let confirmType: ConfirmType
    private let config: Config
    private let analytics: AnalyticsLogger
    private let prompt: String

    public init(
        session: WalletSession,
        keystore: Keystore,
        confirmType: ConfirmType,
        config: Config,
        analytics: AnalyticsLogger,
        prompt: String
    ) {
        self.prompt = prompt
        self.session = session
        self.keystore = keystore
        self.confirmType = confirmType
        self.config = config
        self.analytics = analytics
    }

    public func send(rawTransaction: String) -> Promise<ConfirmResult> {
        let rawRequest = SendRawTransactionRequest(signedTransaction: rawTransaction.add0x)
        let (rpcURL, rpcHeaders) = rpcURLAndHeaders
        let request = EtherServiceRequest(rpcURL: rpcURL, rpcHeaders: rpcHeaders, batch: BatchFactory().create(rawRequest))

        return firstly {
            Session.send(request, server: session.server, analytics: analytics)
        }.recover { error -> Promise<SendRawTransactionRequest.Response> in
            self.logSelectSendError(error)
            throw error
        }.map { transactionID in
            .sentRawTransaction(id: transactionID, original: rawTransaction)
        }.get {
            infoLog("Sent rawTransaction with transactionId: \($0)")
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

    public func send(transaction: UnsignedTransaction) -> Promise<ConfirmResult> {
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
        let (rpcURL, rpcHeaders) = rpcURLAndHeaders
        return firstly {
            GetNextNonce(rpcURL: rpcURL, rpcHeaders: rpcHeaders, server: session.server, wallet: session.account.address, analytics: analytics).promise()
        }.map { nonce -> UnsignedTransaction in
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
        let rawTransaction = SendRawTransactionRequest(signedTransaction: data.hexEncoded)
        let (rpcURL, rpcHeaders) = rpcURLAndHeaders
        let request = EtherServiceRequest(rpcURL: rpcURL, rpcHeaders: rpcHeaders, batch: BatchFactory().create(rawTransaction))

        return firstly {
            Session.send(request, server: session.server, analytics: analytics)
        }.recover { error -> Promise<SendRawTransactionRequest.Response> in
            self.logSelectSendError(error)
            throw error
        }.map { transactionID in
            .sentTransaction(SentTransaction(id: transactionID, original: transaction))
        }.get {
            infoLog("Sent transaction with transactionId: \($0)")
        }
    }

    private func logSelectSendError(_ error: Error) {
        guard let error = error as? SendTransactionNotRetryableError else { return }
        switch error {
        case .nonceTooLow:
            analytics.log(error: Analytics.Error.sendTransactionNonceTooLow)
        case .insufficientFunds, .gasPriceTooLow, .gasLimitTooLow, .gasLimitTooHigh, .possibleChainIdMismatch, .executionReverted:
            break
        }
    }

    private var rpcURLAndHeaders: (url: URL, rpcHeaders: [String: String]) {
        session.server.rpcUrlAndHeadersWithReplacementSendPrivateTransactionsProviderIfEnabled(config: config)
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
