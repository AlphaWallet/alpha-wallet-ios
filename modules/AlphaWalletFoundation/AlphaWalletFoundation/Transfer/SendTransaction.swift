// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation
import PromiseKit
import Combine
import AlphaWalletCore

public class SendTransaction {
    private let keystore: Keystore
    private let blockchainProvider: BlockchainProvider
    private let confirmType: ConfirmType
    private let prompt: String

    public init(blockchainProvider: BlockchainProvider,
                keystore: Keystore,
                confirmType: ConfirmType,
                prompt: String) {

        self.prompt = prompt
        self.blockchainProvider = blockchainProvider
        self.keystore = keystore
        self.confirmType = confirmType
    }

    public func sendPromise(rawTransaction: String) -> Promise<ConfirmResult> {
        return firstly {
            blockchainProvider.sendPromise(rawTransaction: rawTransaction)
        }.map { transactionID in
            .sentRawTransaction(id: transactionID, original: rawTransaction)
        }
    }

    public func sendPublisher(transaction: UnsignedTransaction) -> AnyPublisher<ConfirmResult, PromiseError> {
        if transaction.nonce >= 0 {
            return signAndSend(transaction: transaction)
        } else {
            return blockchainProvider
                .nextNoncePublisher()
                .map { transaction.overriding(nonce: $0) }
                .mapError { PromiseError(error: $0) }
                .flatMap { self.signAndSend(transaction: $0) }
                .eraseToAnyPublisher()
        }
    }

    private func signAndSend(transaction: UnsignedTransaction) -> AnyPublisher<ConfirmResult, PromiseError> {
        return keystore
            .signTransactionPublisher(transaction, prompt: prompt)
            .mapError { PromiseError(error: $0) }
            .flatMap { [confirmType, blockchainProvider] data -> AnyPublisher<ConfirmResult, PromiseError> in
                switch confirmType {
                case .sign:
                    return .just(.signedTransaction(data))
                case .signThenSend:
                    return blockchainProvider
                        .sendPublisher(transaction: transaction, data: data)
                        .map { ConfirmResult.sentTransaction(SentTransaction(id: $0, original: transaction)) }
                        .mapError { PromiseError(error: $0) }
                        .eraseToAnyPublisher()
                }
            }.eraseToAnyPublisher()
    }
}

extension Keystore {
    public func signTransactionPublisher(_ transaction: UnsignedTransaction, prompt: String) -> AnyPublisher<Data, KeystoreError> {
        return AnyPublisher<Data, KeystoreError>.create { seal in
            switch signTransaction(transaction, prompt: prompt) {
            case .success(let data):
                seal.send(data)
                seal.send(completion: .finished)
            case .failure(let error):
                seal.send(completion: .failure(error))
            }

            return AnyCancellable {

            }
        }
    }
}
