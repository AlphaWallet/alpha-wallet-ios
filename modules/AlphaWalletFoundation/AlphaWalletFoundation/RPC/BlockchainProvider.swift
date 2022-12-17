//
//  RpcBlockchainProvider.swift
//  Alamofire
//
//  Created by Vladyslav Shepitko on 19.12.2022.
//

import Foundation
import Combine
import BigInt
import PromiseKit
import AlphaWalletCore

public protocol BlockchainProvider {
    var server: RPCServer { get }
    var wallet: Wallet { get }

    func blockNumberPublisher() -> AnyPublisher<Int, SessionTaskError>
    func transactionsStatePublisher(hash: String) -> AnyPublisher<TransactionState, SessionTaskError>
    func pendingTransactionPublisher(hash: String) -> AnyPublisher<PendingTransaction?, SessionTaskError>
    func callPublisher(from: AlphaWallet.Address?, to: AlphaWallet.Address?, value: String?, data: String) -> AnyPublisher<String, SessionTaskError>
    func gasEstimatesPublisher() -> AnyPublisher<GasEstimates, PromiseError>

    func balancePromise(for address: AlphaWallet.Address) -> Promise<Balance>
    func getTransactionIfCompleted(hash: EthereumTransaction.Hash) -> Promise<PendingTransaction>
    func nextNoncePromise() -> Promise<Int>
    func nextNoncePublisher() -> AnyPublisher<Int, SessionTaskError>
    func gasLimitPublisher(value: BigUInt, toAddress: AlphaWallet.Address?, data: Data) -> AnyPublisher<BigUInt, SessionTaskError>
    func sendPromise(transaction: UnsignedTransaction, data: Data) -> Promise<String>
    func sendPromise(rawTransaction: String) -> Promise<String>
}

public struct BlockchainParams {
    public let maxGasLimit: BigUInt
    public let maxPrice: BigUInt
    public let defaultPrice: BigUInt

    public let canUserChangeGas: Bool
    public let shouldAddBufferWhenEstimatingGasPrice: Bool

    public static func defaultParams(for server: RPCServer) -> BlockchainParams {
        return .init(
            maxGasLimit: GasLimitConfiguration.maxGasLimit(forServer: server),
            maxPrice: GasPriceConfiguration.maxPrice(forServer: server),
            defaultPrice: GasPriceConfiguration.defaultPrice(forServer: server),
            canUserChangeGas: server.canUserChangeGas,
            shouldAddBufferWhenEstimatingGasPrice: server.shouldAddBufferWhenEstimatingGasPrice)
    }
}

public final class RpcBlockchainProvider: BlockchainProvider {
    private let analytics: AnalyticsLogger
    private let nodeApiProvider: NodeApiProvider
    private let params: BlockchainParams

    public let server: RPCServer
    public let wallet: Wallet

    public init(server: RPCServer, account: Wallet, nodeApiProvider: NodeApiProvider, analytics: AnalyticsLogger, params: BlockchainParams) {
        self.analytics = analytics
        self.wallet = account
        self.server = server
        self.params = params
        self.nodeApiProvider = nodeApiProvider
    }

    public func blockNumberPublisher() -> AnyPublisher<Int, SessionTaskError> {
        return nodeApiProvider
            .dataTaskPublisher(BlockNumberRequest())
            .print("xxx.blockNumber")
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    public func balancePromise(for address: AlphaWallet.Address) -> Promise<Balance> {
        return firstly {
            nodeApiProvider.dataTaskPromise(BalanceRequest(address: address, block: .latest))
        }.get {
            print("xxx.getBalance value: \($0)")
        }.recover { e  -> Promise<Balance> in
            print("xxx.getBalance error: \(e)")
            return .init(error: e)
        }
    }

    public func transactionsStatePublisher(hash: String) -> AnyPublisher<TransactionState, SessionTaskError> {
        return nodeApiProvider
            .dataTaskPublisher(TransactionReceiptRequest(hash: hash))
            .map { TransactionState(status: $0.status) }
            .print("xxx.getTransactionsState")
            .eraseToAnyPublisher()
    }

    public func pendingTransactionPublisher(hash: String) -> AnyPublisher<PendingTransaction?, SessionTaskError> {
        return nodeApiProvider
            .dataTaskPublisher(GetTransactionRequest(hash: hash))
            .print("xxx.pendingTransactionPublisher")
            .eraseToAnyPublisher()
    }

    public func callPublisher(from: AlphaWallet.Address?, to: AlphaWallet.Address?, value: String?, data: String) -> AnyPublisher<String, SessionTaskError> {
        return nodeApiProvider
            .dataTaskPublisher(EthCallRequest(from: from, to: to, value: value, data: data, block: .latest))
            .print("xxx.call")
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    public func getTransactionIfCompleted(hash: EthereumTransaction.Hash) -> Promise<PendingTransaction> {
        return nodeApiProvider
            .dataTaskPromise(GetTransactionRequest(hash: hash))
            .map { pendingTransaction in
                if let pendingTransaction = pendingTransaction, let blockNumber = Int(pendingTransaction.blockNumber), blockNumber > 0 {
                    return pendingTransaction
                } else {
                    throw EthereumTransaction.NotCompletedYet()
                }
            }
    }

    public func gasEstimatesPublisher() -> AnyPublisher<GasEstimates, PromiseError> {
        let maxPrice: BigUInt = GasPriceConfiguration.maxPrice(forServer: server)
        let defaultPrice: BigUInt = GasPriceConfiguration.defaultPrice(forServer: server)

        return nodeApiProvider
            .dataTaskPublisher(GasPriceRequest())
            .handleEvents(receiveOutput: { [server] estimate in
                infoLog("Estimated gas price with RPC node server: \(server) estimate: \(estimate)")
            }).map { [params] gasPrice in
                if (gasPrice + GasPriceConfiguration.oneGwei) > maxPrice {
                        // Guard against really high prices
                    return GasEstimates(standard: maxPrice)
                } else {
                    if params.canUserChangeGas && params.shouldAddBufferWhenEstimatingGasPrice {
                        //Add an extra gwei because the estimate is sometimes too low
                        return GasEstimates(standard: gasPrice + GasPriceConfiguration.oneGwei)
                    } else {
                        return GasEstimates(standard: gasPrice)
                    }
                }
            }.catch { _ -> AnyPublisher<GasEstimates, PromiseError> in .just(GasEstimates(standard: defaultPrice)) }
            .receive(on: RunLoop.main)
            .print("xxx.getGasEstimates")
            .eraseToAnyPublisher()
    }

    public func nextNoncePromise() -> Promise<Int> {
        return nodeApiProvider
            .dataTaskPromise(GetTransactionCountRequest(address: wallet.address, block: .pending))
            .get {
                print("xxx.nextNoncePromise value: \($0)")
            }.recover { e  -> Promise<Int> in
                print("xxx.nextNoncePromise error: \(e)")
                return .init(error: e)
            }
    }

    public func nextNoncePublisher() -> AnyPublisher<Int, SessionTaskError> {
        return nodeApiProvider
            .dataTaskPublisher(GetTransactionCountRequest(address: wallet.address, block: .pending))
            .print("xxx.nextNoncePublisher")
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    public func sendPromise(transaction: UnsignedTransaction, data: Data) -> Promise<String> {
        return nodeApiProvider
            .dataTaskPromise(SendRawTransactionRequest(signedTransaction: data.hexEncoded))
            .recover { error -> Promise<SendRawTransactionRequest.Response> in
                self.logSelectSendError(error)
                throw error
            }.get {
                infoLog("Sent transaction with transactionId: \($0)")
            }
    }

    public func sendPromise(rawTransaction: String) -> Promise<String> {
        return nodeApiProvider
            .dataTaskPromise(SendRawTransactionRequest(signedTransaction: rawTransaction.add0x))
            .recover { error -> Promise<SendRawTransactionRequest.Response> in
                self.logSelectSendError(error)
                throw error
            }.get {
                infoLog("Sent rawTransaction with transactionId: \($0)")
            }
    }

    private func logSelectSendError(_ error: Error) {
        guard let error = error as? SendTransactionNotRetryableError else { return }
        switch error {
        case .nonceTooLow:
            analytics.log(error: Analytics.Error.sendTransactionNonceTooLow)
        case .insufficientFunds, .gasPriceTooLow, .gasLimitTooLow, .gasLimitTooHigh, .possibleChainIdMismatch, .executionReverted, .unknown:
            break
        }
    }

    public func gasLimitPublisher(value: BigUInt, toAddress: AlphaWallet.Address?, data: Data) -> AnyPublisher<BigUInt, SessionTaskError> {
        let transactionType = toAddress.flatMap { EstimateGasRequest.TransactionType.normal(to: $0) } ?? .contractDeployment

        let request = EstimateGasRequest(from: wallet.address, transactionType: transactionType, value: value, data: data)

        return nodeApiProvider
            .dataTaskPublisher(request)
            .map { [params] limit -> BigUInt in
                infoLog("Estimated gas limit with eth_estimateGas: \(limit) canCapGasLimit: \(request.canCapGasLimit)")
                let gasLimit: BigUInt = {
                    if limit == GasLimitConfiguration.minGasLimit {
                        return limit
                    }
                    if request.canCapGasLimit {
                        return min(limit + (limit * 20 / 100), params.maxGasLimit)
                    } else {
                        return limit + (limit * 20 / 100)
                    }
                }()
                infoLog("Using gas limit: \(gasLimit)")
                return gasLimit
            }.receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}
