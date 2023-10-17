// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletLogger
import BigInt

public class SignMaySendTransaction {
    private let keystore: Keystore
    private let session: WalletSession
    private let confirmType: ConfirmType
    private let config: Config
    private let analytics: AnalyticsLogger
    private let prompt: String

    public init(session: WalletSession, keystore: Keystore, confirmType: ConfirmType, config: Config, analytics: AnalyticsLogger, prompt: String) {
        self.prompt = prompt
        self.session = session
        self.keystore = keystore
        self.confirmType = confirmType
        self.config = config
        self.analytics = analytics
    }

    public func send(rawTransaction: String) async throws -> ConfirmResult {
        do {
            let transactionId = try await session.blockchainProvider.send(rawTransaction: rawTransaction.add0x).first
            infoLog("Sent rawTransaction with transactionId: \(transactionId)")
            return .sentRawTransaction(id: transactionId, original: rawTransaction)
        } catch {
            self.logSelectSendError(error)
            throw error
        }
    }

    public func signMaybeSend(transaction: UnsignedTransaction) async throws -> ConfirmResult {
        switch confirmType {
        case .sign:
            return try await sign(transaction: transaction)
        case .signThenSend:
            return try await signAndSend(transaction: transaction)
        }
    }

    private func signAndSend(transaction: UnsignedTransaction) async throws -> ConfirmResult {
        if transaction.nonce >= 0 {
            return try await _signAndSend(transaction: transaction)
        } else {
            let nonce = try await session.blockchainProvider.nextNonce(wallet: session.account.address).first
            let transaction = transaction.updating(nonce: nonce)
            return try await _signAndSend(transaction: transaction)
        }
    }

    private func _signAndSend(transaction: UnsignedTransaction) async throws -> ConfirmResult {
        do {
            switch try await keystore.signTransaction(transaction, prompt: prompt) {
            case .failure(let error):
                throw error
            case .success(let data):
                let transactionId = try await session.blockchainProvider.send(rawTransaction: data.hexEncoded).first
                infoLog("Sent transaction with transactionId: \(transactionId)")
                return .sentTransaction(SentTransaction(id: transactionId, original: transaction))
            }
        } catch {
            logSelectSendError(error)
            throw error
        }
    }

    private func sign(transaction: UnsignedTransaction) async throws -> ConfirmResult {
        do {
            switch try await keystore.signTransaction(transaction, prompt: prompt) {
            case .failure(let error):
                throw error
            case .success(let data):
                infoLog("Sign transaction")
                return .signedTransaction(data)
            }
        } catch {
            //TODO should rename the function (since we are only signing, not sending), or have a different function
            logSelectSendError(error)
            throw error
        }
    }

    private func logSelectSendError(_ error: Error) {
        guard let error = error as? SendTransactionNotRetryableError else { return }
        switch error.type {
        case .nonceTooLow:
            analytics.log(error: Analytics.Error.sendTransactionNonceTooLow)
        case .insufficientFunds, .gasPriceTooLow, .gasLimitTooLow, .gasLimitTooHigh, .possibleChainIdMismatch, .executionReverted, .unknown:
            break
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
