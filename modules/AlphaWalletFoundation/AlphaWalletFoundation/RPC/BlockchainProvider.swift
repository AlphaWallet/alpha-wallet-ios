//
//  BlockchainProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 18.01.2023.
//

import Foundation
import Combine
import AlphaWalletLogger
import AlphaWalletWeb3
import BigInt
import AlphaWalletCore

public protocol BlockchainProvider {
    var server: RPCServer { get }

    func balance(for address: AlphaWallet.Address) -> AnyPublisher<Balance, SessionTaskError>
    func blockNumber() -> AnyPublisher<Int, SessionTaskError>
    func transactionsState(hash: String) -> AnyPublisher<TransactionState, SessionTaskError>
    func call(from: AlphaWallet.Address?, to: AlphaWallet.Address?, value: String?, data: String) -> AnyPublisher<String, SessionTaskError>
    func call<R: ContractMethodCall>(_ method: R, block: BlockParameter) -> AnyPublisher<R.Response, SessionTaskError>
    func pendingTransaction(hash: String) -> AnyPublisher<EthereumTransaction?, SessionTaskError>
    func nextNonce(wallet: AlphaWallet.Address) -> AnyPublisher<Int, SessionTaskError>
    func block(by blockNumber: BigUInt) -> AnyPublisher<Date, SessionTaskError>
    func eventLogs(contractAddress: AlphaWallet.Address, eventName: String, abiString: String, filter: EventFilter) -> AnyPublisher<[EventParserResultProtocol], SessionTaskError>
    func gasEstimates() -> AnyPublisher<GasEstimates, PromiseError>
    func gasLimit(wallet: AlphaWallet.Address, value: BigUInt, toAddress: AlphaWallet.Address?, data: Data) -> AnyPublisher<BigUInt, SessionTaskError>
}

extension BlockchainProvider {
    func call<R: ContractMethodCall>(_ method: R, block: BlockParameter = .latest) -> AnyPublisher<R.Response, SessionTaskError> {
        call(method, block: block)
    }
}

public final class RpcBlockchainProvider: BlockchainProvider {
    private let getPendingTransaction: GetPendingTransaction
    private let getEventLogs: GetEventLogs
    private let analytics: AnalyticsLogger
    private lazy var getBlockTimestamp = GetBlockTimestamp(analytics: analytics)
    private lazy var getBlockNumber = GetBlockNumber(server: server, analytics: analytics)
    private lazy var getNextNonce = GetNextNonce(server: server, analytics: analytics)
    private lazy var getTransactionState = GetTransactionState(server: server, analytics: analytics)
    private lazy var getEthBalance = GetEthBalance(forServer: server, analytics: analytics)
    private lazy var getGasPrice = GetGasPrice(server: server, params: params, analytics: analytics)
    private lazy var getGaslimit = GetGasLimit(server: server, analytics: analytics)

    private let params: BlockchainParams
    public let server: RPCServer

    public init(server: RPCServer,
                analytics: AnalyticsLogger,
                params: BlockchainParams) {

        self.params = params
        self.analytics = analytics
        self.server = server
        self.getEventLogs = GetEventLogs()
        self.getPendingTransaction = GetPendingTransaction(server: server, analytics: analytics)
    }

    public func balance(for address: AlphaWallet.Address) -> AnyPublisher<Balance, SessionTaskError> {
        getEthBalance.getBalance(for: address)
            .publisher(queue: .global())
            .mapError { SessionTaskError.responseError($0.embedded) }
            .eraseToAnyPublisher()
    }

    public func call(from: AlphaWallet.Address?, to: AlphaWallet.Address?, value: String?, data: String) -> AnyPublisher<String, SessionTaskError> {
        let request = EthCall(server: server, analytics: analytics)
        return request.ethCall(from: from, to: to, value: value, data: data)
            .publisher()
            .mapError { SessionTaskError.responseError($0.embedded) }
            .eraseToAnyPublisher()
    }

    public func call<R: ContractMethodCall>(_ method: R, block: BlockParameter) -> AnyPublisher<R.Response, SessionTaskError> {
        callSmartContract(withServer: server, contract: method.contract, functionName: method.name, abiString: method.abi, parameters: method.parameters)
            .map { try method.response(from: $0) }
            .publisher()
            .mapError { SessionTaskError.responseError($0.embedded) }
            .eraseToAnyPublisher()
    }

    public func blockNumber() -> AnyPublisher<Int, SessionTaskError> {
        getBlockNumber.getBlockNumber()
            .publisher()
            .mapError { SessionTaskError.responseError($0.embedded) }
            .eraseToAnyPublisher()
    }

    public func transactionsState(hash: String) -> AnyPublisher<TransactionState, SessionTaskError> {
        getTransactionState
            .getTransactionsState(hash: hash)
            .publisher()
            .mapError { SessionTaskError.responseError($0.embedded) }
            .eraseToAnyPublisher()
    }

    public func pendingTransaction(hash: String) -> AnyPublisher<EthereumTransaction?, SessionTaskError> {
        getPendingTransaction.getPendingTransaction(server: server, hash: hash)
    }

    public func block(by blockNumber: BigUInt) -> AnyPublisher<Date, SessionTaskError> {
        getBlockTimestamp.getBlockTimestamp(for: blockNumber, server: server)
            .publisher()
            .mapError { SessionTaskError.responseError($0.embedded) }
            .eraseToAnyPublisher()
    }

    public func eventLogs(contractAddress: AlphaWallet.Address, eventName: String, abiString: String, filter: EventFilter) -> AnyPublisher<[EventParserResultProtocol], SessionTaskError> {
        getEventLogs.getEventLogs(contractAddress: contractAddress, server: server, eventName: eventName, abiString: abiString, filter: filter)
            .publisher()
            .mapError { SessionTaskError.responseError($0.embedded) }
            .eraseToAnyPublisher()
    }

    public func gasEstimates() -> AnyPublisher<GasEstimates, PromiseError> {
        return getGasPrice.getGasEstimates()
            .handleEvents(receiveOutput: { [server] estimate in
                infoLog("[RPC] Estimated gas price with RPC node server: \(server) estimate: \(estimate)")
            }).map { [params] gasPrice in
                if (gasPrice + GasPriceConfiguration.oneGwei) > params.maxPrice {
                    // Guard against really high prices
                    return GasEstimates(standard: params.maxPrice)
                } else {
                    if params.canUserChangeGas && params.shouldAddBufferWhenEstimatingGasPrice {
                        //Add an extra gwei because the estimate is sometimes too low
                        return GasEstimates(standard: gasPrice + GasPriceConfiguration.oneGwei)
                    } else {
                        return GasEstimates(standard: gasPrice)
                    }
                }
            }.catch { [params] _ -> AnyPublisher<GasEstimates, PromiseError> in .just(GasEstimates(standard: params.defaultPrice)) }
            .eraseToAnyPublisher()
    }

    public func nextNonce(wallet: AlphaWallet.Address) -> AnyPublisher<Int, SessionTaskError> {
        getNextNonce.getNextNonce(wallet: wallet)
            .publisher()
            .mapError { SessionTaskError.responseError($0.embedded) }
            .eraseToAnyPublisher()
    }

    public func gasLimit(wallet: AlphaWallet.Address, value: BigUInt, toAddress: AlphaWallet.Address?, data: Data) -> AnyPublisher<BigUInt, SessionTaskError> {
        let transactionType = toAddress.flatMap { EstimateGasTransactionType.normal(to: $0) } ?? .contractDeployment

        return getGaslimit
            .getGasLimit(account: wallet, value: value, transactionType: transactionType, data: data)
            .publisher()
            .mapError { SessionTaskError(error: $0) }
            .map { [params] limit -> BigUInt in
                infoLog("[RPC] Estimated gas limit with eth_estimateGas: \(limit) canCapGasLimit: \(transactionType.canCapGasLimit)")
                let gasLimit: BigUInt = {
                    if limit == GasLimitConfiguration.minGasLimit {
                        return limit
                    }
                    if transactionType.canCapGasLimit {
                        return min(limit + (limit * 20 / 100), params.maxGasLimit)
                    } else {
                        return limit + (limit * 20 / 100)
                    }
                }()
                infoLog("[RPC] Using gas limit: \(gasLimit)")
                return gasLimit
            }.eraseToAnyPublisher()
    }

}
