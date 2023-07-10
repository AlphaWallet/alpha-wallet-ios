//
//  BlockchainProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 18.01.2023.
//

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletLogger
import AlphaWalletWeb3
import APIKit
import BigInt
import JSONRPCKit

public protocol BlockchainProvider: BlockchainCallable {
    var server: RPCServer { get }

    func balance(for address: AlphaWallet.Address) -> AnyPublisher<Balance, SessionTaskError>
    func blockNumber() -> AnyPublisher<Int, SessionTaskError>
    func transactionReceipt(hash: String) -> AnyPublisher<TransactionReceipt, SessionTaskError>
    func call(from: AlphaWallet.Address?, to: AlphaWallet.Address?, value: String?, data: String) -> AnyPublisher<String, SessionTaskError>
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

public final class RpcBlockchainProvider: BlockchainProvider {
    private let getEventLogs: GetEventLogs
    private let analytics: AnalyticsLogger
    private let config: Config = Config()
    private let params: BlockchainParams
    private var rpcURLAndHeaders: (url: URL, rpcHeaders: [String: String]) {
        server.rpcUrlAndHeadersWithReplacementSendPrivateTransactionsProviderIfEnabled(config: config)
    }

    public let server: RPCServer

    public init(server: RPCServer,
                analytics: AnalyticsLogger,
                params: BlockchainParams) {

        self.params = params
        self.analytics = analytics
        self.server = server
        self.getEventLogs = GetEventLogs()
    }

    public func send(rawTransaction: String) -> AnyPublisher<String, SessionTaskError> {
        let payload = SendRawTransactionRequest(signedTransaction: rawTransaction.add0x)
        let (rpcURL, rpcHeaders) = rpcURLAndHeaders
        let request = EtherServiceRequest(rpcURL: rpcURL, rpcHeaders: rpcHeaders, batch: BatchFactory().create(payload))

        return APIKitSession.sendPublisher(request, server: server, analytics: analytics)
    }

    public func getChainId() -> AnyPublisher<Int, SessionTaskError> {
        let request = ChainIdRequest()
        return APIKitSession.sendPublisher(EtherServiceRequest(server: server, batch: BatchFactory().create(request)), server: server, analytics: analytics)
    }

    public func nextNonce(wallet: AlphaWallet.Address) -> AnyPublisher<Int, SessionTaskError> {
        let payload = GetTransactionCountRequest(address: wallet, state: "pending")
        let (rpcURL, rpcHeaders) = rpcURLAndHeaders
        let request = EtherServiceRequest(rpcURL: rpcURL, rpcHeaders: rpcHeaders, batch: BatchFactory().create(payload))

        return APIKitSession.sendPublisher(request, server: server, analytics: analytics)
    }

    public func balance(for address: AlphaWallet.Address) -> AnyPublisher<Balance, SessionTaskError> {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(BalanceRequest(address: address)))

        return APIKitSession.sendPublisher(request, server: server, analytics: analytics)
    }

    public func call(from: AlphaWallet.Address?, to: AlphaWallet.Address?, value: String?, data: String) -> AnyPublisher<String, SessionTaskError> {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(EthCallRequest(from: from, to: to, value: value, data: data)))

        return APIKitSession.sendPublisher(request, server: server, analytics: analytics)
    }

    public func call<R: ContractMethodCall>(_ method: R, block: BlockParameter) -> AnyPublisher<R.Response, SessionTaskError> {
        callSmartContract(withServer: server, contract: method.contract, functionName: method.name, abiString: method.abi, parameters: method.parameters)
            .map { try method.response(from: $0) }
            .publisher()
            .mapError { SessionTaskError.responseError($0.embedded) }
            .eraseToAnyPublisher()
    }

    public func blockNumber() -> AnyPublisher<Int, SessionTaskError> {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(BlockNumberRequest()))

        return APIKitSession.sendPublisher(request, server: server, analytics: analytics)
    }

    public func transactionReceipt(hash: String) -> AnyPublisher<TransactionReceipt, SessionTaskError> {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(TransactionReceiptRequest(hash: hash)))

        return APIKitSession.sendPublisher(request, server: server, analytics: analytics)
    }

    public func transaction(byHash hash: String) -> AnyPublisher<EthereumTransaction?, SessionTaskError> {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(GetTransactionRequest(hash: hash)))

        return APIKitSession.sendPublisher(request, server: server, analytics: analytics)
    }

    public func block(by blockNumber: BigUInt) -> AnyPublisher<Block, SessionTaskError> {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(BlockByNumberRequest(number: blockNumber)))

        return APIKitSession.sendPublisher(request, server: server, analytics: analytics)
    }

    public func feeHistory(blockCount: Int, block: BlockParameter, rewardPercentile: [Int]) -> AnyPublisher<FeeHistory, SessionTaskError> {
        let payload = FeeHistoryRequest(blockCount: blockCount, lastBlock: block.rawValue, rewardPercentile: rewardPercentile)
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(payload))

        return APIKitSession.sendPublisher(request, server: server, analytics: analytics)
    }

    public func eventLogs(contractAddress: AlphaWallet.Address, eventName: String, abiString: String, filter: EventFilter) -> AnyPublisher<[EventParserResultProtocol], SessionTaskError> {
        getEventLogs.getEventLogs(contractAddress: contractAddress, server: server, eventName: eventName, abiString: abiString, filter: filter)
            .publisher()
            .mapError { SessionTaskError.responseError($0.embedded) }
            .eraseToAnyPublisher()
    }

    public func gasEstimates() -> AnyPublisher<LegacyGasEstimates, PromiseError> {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(GasPriceRequest()))

        return APIKitSession.sendPublisher(request, server: server, analytics: analytics)
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
            .eraseToAnyPublisher()
    }

    public func gasLimit(wallet: AlphaWallet.Address, value: BigUInt, toAddress: AlphaWallet.Address?, data: Data) -> AnyPublisher<BigUInt, SessionTaskError> {
        let transactionType = toAddress.flatMap { EstimateGasTransactionType.normal(to: $0) } ?? .contractDeployment
        let payload = EstimateGasRequest(from: wallet, transactionType: transactionType, value: value, data: data)
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(payload))

        return APIKitSession.sendPublisher(request, server: server, analytics: analytics)
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

public typealias APIKitSession = APIKit.Session
public typealias SessionTaskError = APIKit.SessionTaskError
public typealias JSONRPCError = JSONRPCKit.JSONRPCError

extension SessionTaskError {
    public init(error: Error) {
        if let e = error as? SessionTaskError {
            self = e
        } else {
            self = .responseError(error)
        }
    }

    public var unwrapped: Error {
        switch self {
        case .connectionError(let e):
            return e
        case .requestError(let e):
            return e
        case .responseError(let e):
            return e
        }
    }
}

extension JSONRPCKit.JSONRPCError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .responseError(_, let message, _):
            return message
        case .responseNotFound:
            return "Response Not Found"
        case .resultObjectParseError:
            return "Result Object Parse Error"
        case .errorObjectParseError:
            return "Error Object Parse Error"
        case .unsupportedVersion(let string):
            return "Unsupported Version \(string)"
        case .unexpectedTypeObject:
            return "Unexpected Type Object"
        case .missingBothResultAndError:
            return "Missing Both Result And Error"
        case .nonArrayResponse:
            return "Non Array Response"
        }
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
