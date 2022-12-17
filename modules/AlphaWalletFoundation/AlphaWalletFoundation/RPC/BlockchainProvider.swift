//
//  BlockchainProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 18.01.2023.
//

import Foundation
import Combine
import AlphaWalletLogger
import BigInt
import AlphaWalletCore
import AlphaWalletWeb3

public protocol BlockchainProvider {
    var server: RPCServer { get }

    func balance(for address: AlphaWallet.Address) -> AnyPublisher<Balance, SessionTaskError>
    func blockNumber() -> AnyPublisher<Int, SessionTaskError>
    func transactionReceipt(hash: String) -> AnyPublisher<TransactionReceipt, SessionTaskError>
    func call(from: AlphaWallet.Address?, to: AlphaWallet.Address?, value: String?, data: String) -> AnyPublisher<String, SessionTaskError>
    func call<R: ContractMethodCall>(_ method: R, block: BlockParameter) -> AnyPublisher<R.Response, SessionTaskError>
    func transaction(byHash hash: String) -> AnyPublisher<EthereumTransaction?, SessionTaskError>
    func nextNonce(wallet: AlphaWallet.Address) -> AnyPublisher<Int, SessionTaskError>
    func block(by blockNumber: BigUInt) -> AnyPublisher<Block, SessionTaskError>
    func eventLogs(contractAddress: AlphaWallet.Address, eventName: String, abiString: String, filter: EventFilter) -> AnyPublisher<[EventParserResultProtocol], SessionTaskError>
    func gasEstimates() -> AnyPublisher<LegacyGasEstimates, PromiseError>
    func gasLimit(wallet: AlphaWallet.Address, value: BigUInt, toAddress: AlphaWallet.Address?, data: Data) -> AnyPublisher<BigUInt, SessionTaskError>
    func send(rawTransaction: String) -> AnyPublisher<String, SessionTaskError>
    func getChainId() -> AnyPublisher<Int, SessionTaskError>
    func feeHistory(blockCount: Int, block: BlockParameter, rewardPercentile: [Int]) -> AnyPublisher<FeeHistory, SessionTaskError>
}

extension BlockchainProvider {
    func call<R: ContractMethodCall>(_ method: R, block: BlockParameter = .latest) -> AnyPublisher<R.Response, SessionTaskError> {
        call(method, block: block)
    }
}

public final class RpcBlockchainProvider: BlockchainProvider {
    private let analytics: AnalyticsLogger
    private let rpcRequestProvider: RpcRequestDispatcher
    private let params: BlockchainParams
    private let getEventLogs: GetEventLogs
    private let cachableContractMethodCall: CachableContractMethodCallProvider
    public let server: RPCServer

    public init(server: RPCServer,
                rpcRequestProvider: RpcRequestDispatcher,
                analytics: AnalyticsLogger,
                params: BlockchainParams) {

        self.cachableContractMethodCall = CachableContractMethodCallProvider(rpcRequestProvider: rpcRequestProvider)
        self.getEventLogs = GetEventLogs(rpcRequestProvider: rpcRequestProvider)
        self.analytics = analytics
        self.server = server
        self.params = params
        self.rpcRequestProvider = rpcRequestProvider
    }

    public func getChainId() -> AnyPublisher<Int, SessionTaskError> {
        return rpcRequestProvider.send(request: .chainId())
            .tryMap { try ChainIdDecoder().decode(response: $0) }
            .mapError { SessionTaskError(error: $0) }
            .print("xxx.chainId for server: \(server)")
            .eraseToAnyPublisher()
    }

    public func block(by blockNumber: BigUInt) -> AnyPublisher<Block, SessionTaskError> {
        return rpcRequestProvider.send(request: .getBlockByNumber(number: blockNumber))
            .tryMap { try BlockByNumberDecoder().decode(response: $0) }
            .mapError { SessionTaskError(error: $0) }
            .print("xxx.block(by: for server: \(server)")
            .eraseToAnyPublisher()
    }

    public func blockNumber() -> AnyPublisher<Int, SessionTaskError> {
        return rpcRequestProvider.send(request: .blockNumber())
            .tryMap { try BlockNumberDecoder().decode(response: $0) }
            .mapError { SessionTaskError(error: $0) }
            .receive(on: RunLoop.main)
            .print("xxx.blockNumber")
            .eraseToAnyPublisher()
    }

    public func call<R: ContractMethodCall>(_ method: R, block: BlockParameter) -> AnyPublisher<R.Response, SessionTaskError> {
        return cachableContractMethodCall
            .call(method, block: block)
            .print("xxx.call for \(method.contract)")
            .eraseToAnyPublisher()
    }

    //TODO: might be needed to handle of several call issue. applicatable for multiple rpc urls,
    //we applying inflight promises/publishers for rpc calls, but it could not work when balance is going to be fetched with another rpc url.
    public func balance(for address: AlphaWallet.Address) -> AnyPublisher<Balance, SessionTaskError> {
        return rpcRequestProvider.send(request: .getBalance(address: address))
            .tryMap { try BalanceDecoder().decode(response: $0) }
            .mapError { SessionTaskError(error: $0) }
            .print("xxx.balance for \(address)")
            .eraseToAnyPublisher()
    }

    public func transactionReceipt(hash: String) -> AnyPublisher<TransactionReceipt, SessionTaskError> {
        return rpcRequestProvider.send(request: .getTransactionReceipt(hash: hash))
            .tryMap { try TransactionReceiptDecoder().decode(response: $0) }
            .mapError { SessionTaskError(error: $0) }
            .print("xxx.transactionReceipt")
            .eraseToAnyPublisher()
    }

    public func transaction(byHash hash: String) -> AnyPublisher<EthereumTransaction?, SessionTaskError> {
        return rpcRequestProvider.send(request: .getTransactionReceipt(hash: hash))
            .tryMap { try PendingTransactionDecoder(hash: hash).decode(response: $0) }
            .mapError { SessionTaskError(error: $0) }
            .print("xxx.pendingTransaction")
            .eraseToAnyPublisher()
    }

    public func feeHistory(blockCount: Int, block: BlockParameter, rewardPercentile: [Int]) -> AnyPublisher<FeeHistory, SessionTaskError> {
        return rpcRequestProvider.send(request: .feeHistory(blockCount: blockCount, lastBlock: block.rawValue, rewardPercentile: rewardPercentile))
            .tryMap { try FeeHistoryDecoder().decode(response: $0) }
            .mapError { SessionTaskError(error: $0) }
            .print("xxx.feeHistory")
            .eraseToAnyPublisher()
    }

    public func eventLogs(contractAddress: AlphaWallet.Address, eventName: String, abiString: String, filter: EventFilter) -> AnyPublisher<[EventParserResultProtocol], SessionTaskError> {
        getEventLogs.getEventLogs(contractAddress: contractAddress, eventName: eventName, abiString: abiString, filter: filter)
    }

    public func gasEstimates() -> AnyPublisher<LegacyGasEstimates, PromiseError> {
        return rpcRequestProvider.send(request: .gasPrice())
            .tryMap { try BigUIntDecoder().decode(response: $0) }
            .mapError { SessionTaskError(error: $0) }
            .handleEvents(receiveOutput: { [server] estimate in
                infoLog("[RPC] Estimated gas price with RPC node server: \(server) estimate: \(estimate)")
            }).map { [params] gasPrice in
                //Add an extra gwei because the estimate is sometimes too low. We mustn't do this if the gas price estimated is lower than 1gwei since chains like Arbitrum is cheap (0.1gwei as of 20230320)
                let bufferedGasPrice = params.gasPriceBuffer.bufferedGasPrice(estimatedGasPrice: gasPrice)

                if bufferedGasPrice.value > params.maxPrice {
                    // Guard against really high prices
                    return LegacyGasEstimates(standard: params.maxPrice)
                } else {
                    //We also check to make sure the buffer is not significant compared to the original gas price
                    if params.canUserChangeGas && params.shouldAddBufferWhenEstimatingGasPrice, gasPrice > bufferedGasPrice.buffer {
                        return LegacyGasEstimates(standard: bufferedGasPrice.value)
                    } else {
                        return LegacyGasEstimates(standard: gasPrice)
                    }
                }
            }.catch { [params] _ -> AnyPublisher<LegacyGasEstimates, PromiseError> in .just(LegacyGasEstimates(standard: params.defaultPrice)) }
            .receive(on: RunLoop.main)
            .print("xxx.gasPrice")
            .eraseToAnyPublisher()
    }

    public func nextNonce(wallet: AlphaWallet.Address) -> AnyPublisher<Int, SessionTaskError> {
        return rpcRequestProvider.send(request: .getTransactionCount(address: wallet, block: .pending), policy: .noBatching)
            .tryMap { try TransactionCountDecoder().decode(response: $0) }
            .mapError { SessionTaskError(error: $0) }
            .receive(on: RunLoop.main)
            .print("xxx.getTransactionCount")
            .eraseToAnyPublisher()
    }

    public func call(from: AlphaWallet.Address?, to: AlphaWallet.Address?, value: String?, data: String) -> AnyPublisher<String, SessionTaskError> {
        return rpcRequestProvider.send(request: .call(from: from, to: to, value: value, data: data, block: .latest), policy: .noBatching)
            .tryMap { try $0.decode(type: String.self) }
            .mapError { SessionTaskError(error: $0) }
            .receive(on: RunLoop.main)
            .print("xxx.call")
            .eraseToAnyPublisher()
    }

    public func send(rawTransaction: String) -> AnyPublisher<String, SessionTaskError> {
        return rpcRequestProvider.send(request: .sendRawTransaction(rawTransaction: rawTransaction), policy: .noBatching)
            .tryMap { try $0.decode(type: String.self) }
            .mapError { SessionTaskError(error: $0) }
            .receive(on: RunLoop.main)
            .print("xxx.send(rawTransaction")
            .handleEvents(receiveOutput: {
                infoLog("Sent transaction with transactionId: \($0)")
            }, receiveCompletion: { result in
                guard case .failure(let error) = result else { return }
                self.logSelectSendError(error)
            }).eraseToAnyPublisher()
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

    public func gasLimit(wallet: AlphaWallet.Address, value: BigUInt, toAddress: AlphaWallet.Address?, data: Data) -> AnyPublisher<BigUInt, SessionTaskError> {
        let transactionType = toAddress.flatMap { EstimateGasTransactionType.normal(to: $0) } ?? .contractDeployment

        return rpcRequestProvider.send(request: .estimateGas(from: wallet, transactionType: transactionType, value: value, data: data), policy: .noBatching)
            .tryMap { try BigUIntDecoder().decode(response: $0) }
            .mapError { SessionTaskError(error: $0) }
            .map { [params] limit -> BigUInt in
                infoLog("[RPC] Estimated gas limit with eth_estimateGas: \(limit) canCapGasLimit: \(transactionType.canCapGasLimit)")
                let gasLimit: BigUInt = {
                    if limit == params.minGasLimit {
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

public enum GasPriceBuffer {
    case percentage(BigUInt)
    case fixed(BigUInt)

    public func bufferedGasPrice(estimatedGasPrice: BigUInt) -> (value: BigUInt, buffer: BigUInt) {
        let buffer: BigUInt
        switch self {
        case .percentage(let bufferPercent):
            buffer = estimatedGasPrice * bufferPercent / BigUInt(100)
        case .fixed(let value):
            buffer = value
        }

        return (estimatedGasPrice + buffer, buffer)
    }
}
