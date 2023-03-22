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
import APIKit
import JSONRPCKit

public protocol BlockchainProvider {
    var server: RPCServer { get }

    func balance(for address: AlphaWallet.Address) async throws -> Balance
    func blockNumber() async throws -> Int
    func transactionReceipt(hash: String) async throws -> TransactionReceipt
    func call(from: AlphaWallet.Address?, to: AlphaWallet.Address?, value: String?, data: String) async throws -> String
    func call<R: ContractMethodCall>(_ method: R, block: BlockParameter) -> AnyPublisher<R.Response, SessionTaskError>
    func transaction(byHash hash: String) async throws -> EthereumTransaction?
    func nextNonce(wallet: AlphaWallet.Address) async throws -> Int
    func block(by blockNumber: BigUInt) async throws -> Block
    func eventLogs(contractAddress: AlphaWallet.Address, eventName: String, abiString: String, filter: EventFilter) -> AnyPublisher<[EventParserResultProtocol], SessionTaskError>
    func gasEstimates() async throws -> GasEstimates
    func gasLimit(wallet: AlphaWallet.Address, value: BigUInt, toAddress: AlphaWallet.Address?, data: Data) async throws -> BigUInt
    func send(rawTransaction: String) async throws -> String
}

extension BlockchainProvider {
    func call<R: ContractMethodCall>(_ method: R, block: BlockParameter = .latest) -> AnyPublisher<R.Response, SessionTaskError> {
        call(method, block: block)
    }
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

    public func send(rawTransaction: String) async throws -> String {
        let payload = SendRawTransactionRequest(signedTransaction: rawTransaction.add0x)
        let (rpcURL, rpcHeaders) = rpcURLAndHeaders
        let request = EtherServiceRequest(rpcURL: rpcURL, rpcHeaders: rpcHeaders, batch: BatchFactory().create(payload))
        
        return try await APIKitSession.sendPublisher(request, server: server, analytics: analytics).first
    }

    public func nextNonce(wallet: AlphaWallet.Address) async throws -> Int {
        let payload = GetTransactionCountRequest(address: wallet, state: "pending")
        let (rpcURL, rpcHeaders) = rpcURLAndHeaders
        let request = EtherServiceRequest(rpcURL: rpcURL, rpcHeaders: rpcHeaders, batch: BatchFactory().create(payload))

        return try await APIKitSession.sendPublisher(request, server: server, analytics: analytics).first
    }

    public func balance(for address: AlphaWallet.Address) async throws -> Balance {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(BalanceRequest(address: address)))

        return try await APIKitSession.sendPublisher(request, server: server, analytics: analytics).first
    }

    public func call(from: AlphaWallet.Address?, to: AlphaWallet.Address?, value: String?, data: String) async throws -> String {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(EthCallRequest(from: from, to: to, value: value, data: data)))

        return try await APIKitSession.sendPublisher(request, server: server, analytics: analytics).first
    }

    public func call<R: ContractMethodCall>(_ method: R, block: BlockParameter) -> AnyPublisher<R.Response, SessionTaskError> {
        callSmartContract(withServer: server, contract: method.contract, functionName: method.name, abiString: method.abi, parameters: method.parameters)
            .map { try method.response(from: $0) }
            .publisher()
            .mapError { SessionTaskError.responseError($0.embedded) }
            .eraseToAnyPublisher()
    }

    public func blockNumber() async throws -> Int {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(BlockNumberRequest()))

        return try await APIKitSession.sendPublisher(request, server: server, analytics: analytics).first
    }

    public func transactionReceipt(hash: String) async throws -> TransactionReceipt {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(TransactionReceiptRequest(hash: hash)))

        return try await APIKitSession.sendPublisher(request, server: server, analytics: analytics).first
    }

    public func transaction(byHash hash: String) async throws -> EthereumTransaction? {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(GetTransactionRequest(hash: hash)))

        return try await APIKitSession.sendPublisher(request, server: server, analytics: analytics).first
    }

    public func block(by blockNumber: BigUInt) async throws -> Block {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(BlockByNumberRequest(number: blockNumber)))

        return try await APIKitSession.sendPublisher(request, server: server, analytics: analytics).first
    }

    public func eventLogs(contractAddress: AlphaWallet.Address, eventName: String, abiString: String, filter: EventFilter) -> AnyPublisher<[EventParserResultProtocol], SessionTaskError> {
        getEventLogs.getEventLogs(contractAddress: contractAddress, server: server, eventName: eventName, abiString: abiString, filter: filter)
            .publisher()
            .mapError { SessionTaskError.responseError($0.embedded) }
            .eraseToAnyPublisher()
    }

    public func gasEstimates() async throws -> GasEstimates {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(GasPriceRequest()))
        do {
            let gasPrice = try await APIKitSession.sendPublisher(request, server: server, analytics: analytics).first
            infoLog("[RPC] Estimated gas price with RPC node server: \(server) estimate: \(gasPrice)")
            if (gasPrice + GasPriceConfiguration.oneGwei) > params.maxPrice {
                // Guard against really high prices
                return GasEstimates(standard: params.maxPrice)
            } else {
                if params.canUserChangeGas && params.shouldAddBufferWhenEstimatingGasPrice, gasPrice > GasPriceConfiguration.oneGwei {
                    //Add an extra gwei because the estimate is sometimes too low. We mustn't do this if the gas price estimated is lower than 1gwei since chains like Arbitrum is cheap (0.1gwei as of 20230320)
                    return GasEstimates(standard: gasPrice + GasPriceConfiguration.oneGwei)
                } else {
                    return GasEstimates(standard: gasPrice)
                }
            }
        } catch {
            return GasEstimates(standard: params.defaultPrice)
        }
    }

    public func gasLimit(wallet: AlphaWallet.Address, value: BigUInt, toAddress: AlphaWallet.Address?, data: Data) async throws -> BigUInt {
        let transactionType = toAddress.flatMap { EstimateGasTransactionType.normal(to: $0) } ?? .contractDeployment
        let payload = EstimateGasRequest(from: wallet, transactionType: transactionType, value: value, data: data)
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(payload))
        let gasLimit = try await APIKitSession.sendPublisher(request, server: server, analytics: analytics).first

        infoLog("[RPC] Estimated gas limit with eth_estimateGas: \(gasLimit) canCapGasLimit: \(transactionType.canCapGasLimit)")

        var adjustedGasLimit: BigUInt
        if gasLimit == params.minGasLimit {
            adjustedGasLimit = gasLimit
        }
        if transactionType.canCapGasLimit {
            adjustedGasLimit = min(gasLimit + (gasLimit * 20 / 100), params.maxGasLimit)
        } else {
            adjustedGasLimit = gasLimit + (gasLimit * 20 / 100)
        }

        infoLog("[RPC] Using gas limit: \(adjustedGasLimit)")
        return adjustedGasLimit
    }

}
