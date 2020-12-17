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
    private let formatter = EtherNumberFormatter.full
    private let confirmType: ConfirmType

    init(
        session: WalletSession,
        keystore: Keystore,
        confirmType: ConfirmType
    ) {
        self.session = session
        self.keystore = keystore
        self.confirmType = confirmType
    }

    func send(
        transaction: UnsignedTransaction,
        completion: @escaping (ResultResult<ConfirmResult, AnyError>.t) -> Void
    ) {
        if transaction.nonce >= 0 {
            signAndSend(transaction: transaction, completion: completion)
        } else {
            firstly {
                GetNextNonce(server: session.server, wallet: session.account.address).promise()
            }.done {
                let transaction = self.appendNonce(to: transaction, currentNonce: $0)
                self.signAndSend(transaction: transaction, completion: completion)
            }.catch {
                completion(.failure(AnyError($0)))
            }
        }
    }

    func send(rawTransaction: String) -> Promise<ConfirmResult> {
        return Promise { seal in
            let request = EtherServiceRequest(server: session.server, batch: BatchFactory().create(SendRawTransactionRequest(signedTransaction: rawTransaction.add0x)))
            Session.send(request) { result in
                switch result {
                case .success(let transactionID):
                    seal.fulfill(.sentRawTransaction(id: transactionID, original: rawTransaction))
                case .failure(let error):
                    seal.reject(AnyError(error))
                }
            }
        }
    }

    func send(transaction: UnsignedTransaction) -> Promise<ConfirmResult> {
        Promise { seal in
            send(transaction: transaction) { result in
                switch result {
                case .success(let result):
                    seal.fulfill(result)
                case .failure(let error):
                    seal.reject(error)
                }
            }
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
            server: to.server
        )
    }

    func signAndSend(
        transaction: UnsignedTransaction,
        completion: @escaping (ResultResult<ConfirmResult, AnyError>.t) -> Void
    ) {
        let signedTransaction = keystore.signTransaction(transaction)
        switch signedTransaction {
        case .success(let data):
            switch confirmType {
            case .sign:
                completion(.success(.signedTransaction(data)))
            case .signThenSend:
                let request = EtherServiceRequest(server: session.server, batch: BatchFactory().create(SendRawTransactionRequest(signedTransaction: data.hexEncoded)))
                firstly {
                    Session.send(request)
                }.done { transactionID in
                    completion(.success(.sentTransaction(SentTransaction(id: transactionID, original: transaction))))
                }.catch { error in
                    completion(.failure(AnyError(error)))
                }
            }
        case .failure(let error):
            completion(.failure(AnyError(error)))
        }
    }
}
