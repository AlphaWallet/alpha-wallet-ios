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

    init(
        session: WalletSession,
        keystore: Keystore,
        confirmType: ConfirmType,
        config: Config
    ) {
        self.session = session
        self.keystore = keystore
        self.confirmType = confirmType
        self.config = config
    }

    func send(rawTransaction: String) -> Promise<ConfirmResult> {
        let rawRequest = SendRawTransactionRequest(signedTransaction: rawTransaction.add0x)
        let request = EtherServiceRequest(rpcURL: rpcURL, batch: BatchFactory().create(rawRequest))

        return firstly {
            Session.send(request)
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
            GetNextNonce(server: session.server, wallet: session.account.address).promise()
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
        }.map { transactionID in
            .sentTransaction(SentTransaction(id: transactionID, original: transaction))
        }.get {
            info("Sent transaction with transactionId: \($0)")
        }
    }

    private var rpcURL: URL {
        session.server.rpcURLReplaceMainWithPrivateNetworkIfNeeded(config: config)
    }
}

fileprivate extension RPCServer {
    func rpcURLReplaceMainWithPrivateNetworkIfNeeded(config: Config) -> URL {
        switch self {
        case .main where config.usePrivateNetwork:
            if let url = config.privateRpcUrl {
                return url
            } else {
                return rpcURL
            }
        case .xDai, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .main, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .palm, .palmTestnet:
            return self.rpcURL
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
