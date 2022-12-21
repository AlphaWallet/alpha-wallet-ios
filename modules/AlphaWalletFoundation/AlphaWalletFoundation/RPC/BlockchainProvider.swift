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
import AlphaWalletWeb3

public protocol BlockchainProvider {
    var server: RPCServer { get }
    var wallet: Wallet { get }
    var params: BlockchainParams { get }

    func blockNumberPublisher() -> AnyPublisher<Int, SessionTaskError>
    func transactionsStatePublisher(hash: String) -> AnyPublisher<TransactionState, SessionTaskError>
    func pendingTransactionPublisher(hash: String) -> AnyPublisher<PendingTransaction?, SessionTaskError>
    func callPublisher(from: AlphaWallet.Address?, to: AlphaWallet.Address?, value: String?, data: String) -> AnyPublisher<String, SessionTaskError>
    func callPromise<R: ContractMethodCall>(_ method: R) -> Promise<R.Response>
    func callPublisher<R: ContractMethodCall>(_ method: R) -> AnyPublisher<R.Response, SessionTaskError>

    func gasEstimatesPublisher() -> AnyPublisher<GasEstimates, PromiseError>

    func balancePublisher(for address: AlphaWallet.Address) -> AnyPublisher<Balance, SessionTaskError>
    func getTransactionIfCompleted(hash: EthereumTransaction.Hash) -> Promise<PendingTransaction>
    func nextNoncePromise() -> Promise<Int>
    func nextNoncePublisher() -> AnyPublisher<Int, SessionTaskError>
    func gasLimitPublisher(value: BigUInt, toAddress: AlphaWallet.Address?, data: Data) -> AnyPublisher<BigUInt, SessionTaskError>
    func sendPublisher(transaction: UnsignedTransaction, data: Data) -> AnyPublisher<String, SessionTaskError>
    func sendPromise(rawTransaction: String) -> Promise<String>
    func blockByNumberPromise(blockNumber: BigUInt) -> Promise<Block>
    func eventLogsPromise(contractAddress: AlphaWallet.Address, eventName: String, abiString: String, filter: EventFilter) -> Promise<[EventParserResultProtocol]>
}

public enum ExplorerType: Codable {
    case etherscan(url: URL, api: String)
    case blockscout(url: URL)
    case none
}

//NOTE: rename 
public protocol SessionsParamsStorage {
    func sessionParams(chainId: Int) -> SessionParams
}

public protocol PrivateNetworkRpcNodeParamsProvider {
    func rpcNodeParams(server: RPCServer) -> PrivateNetworkParams?
}

extension Config: PrivateNetworkRpcNodeParamsProvider {
    public func rpcNodeParams(server: RPCServer) -> PrivateNetworkParams? {
        sendPrivateTransactionsProvider?.rpcUrl(forServer: server).flatMap { PrivateNetworkParams(rpcUrl: $0, headers: [:]) }
    }
}

public class SessionsParamsFileStorage: SessionsParamsStorage {
    private let storage: Storage<[Int: SessionParams]>
    private let privateNetworkRpcNodeParamsProvider: PrivateNetworkRpcNodeParamsProvider

    public init(privateNetworkRpcNodeParamsProvider: PrivateNetworkRpcNodeParamsProvider, fileName: String = "Keys.storageFileKey") {
        storage = .init(fileName: fileName, defaultValue: [:])
        self.privateNetworkRpcNodeParamsProvider = privateNetworkRpcNodeParamsProvider
    }

    public func sessionParams(chainId: Int) -> SessionParams {
        let server = RPCServer(chainID: chainId)
        let rpcNodeParamsForPrivateNetwork = privateNetworkRpcNodeParamsProvider.rpcNodeParams(server: server)

        if let params = storage.value[chainId] {
            return params.overriding(rpcSource: params.rpcSource.adding(privateParams: rpcNodeParamsForPrivateNetwork))
        } else {
            let params = SessionParams(server: server)
            var allParams = storage.value
            allParams[chainId] = params

            storage.value = allParams

            return params.overriding(rpcSource: params.rpcSource.adding(privateParams: rpcNodeParamsForPrivateNetwork))
        }
    }
}

//TODO: maybe rename, don't know
public struct SessionParams: Codable {
    public let chainId: Int
    public var overridenChainId: Int?
    public var chainName: String
    public var cryptoCurrencyName: String?
    public var rpcSource: RpcSource
    public var explorer: ExplorerType
    public var etherscanCompatibleType: RPCServer.EtherscanCompatibleType
    public var isTestnet: Bool

    public init(chainId: Int,
                overridenChainId: Int?,
                chainName: String,
                cryptoCurrencyName: String?,
                rpcSource: RpcSource,
                explorer: ExplorerType,
                etherscanCompatibleType: RPCServer.EtherscanCompatibleType,
                isTestnet: Bool) {
        self.overridenChainId = nil
        self.chainId = chainId
        self.chainName = chainName
        self.cryptoCurrencyName = cryptoCurrencyName
        self.rpcSource = rpcSource
        self.explorer = explorer
        self.etherscanCompatibleType = etherscanCompatibleType
        self.isTestnet = isTestnet
    }

    func overriding(rpcSource: RpcSource) -> SessionParams {
        SessionParams(
            chainId: chainId,
            overridenChainId: overridenChainId,
            chainName: chainName,
            cryptoCurrencyName: cryptoCurrencyName,
            rpcSource: rpcSource,
            explorer: explorer,
            etherscanCompatibleType: etherscanCompatibleType,
            isTestnet: isTestnet)
    }

    public init(server: RPCServer) {
        self.chainId = server.chainID
        self.chainName = server.name
        self.cryptoCurrencyName = server.cryptoCurrencyName
        self.rpcSource = .http(params: .init(rpcUrls: [server.rpcURL], headers: [:]), privateParams: nil)
        self.explorer = server.etherscanApiRoot.flatMap { ExplorerType.etherscan(url: $0, api: "<apiKey>") } ?? .none

        self.etherscanCompatibleType = server.etherscanCompatibleType
        self.isTestnet = server.isTestnet
    }

    public var blockchainParams: BlockchainParams {
        return .defaultParams(for: server)
    }

    public var server: RPCServer {
        RPCServer(chainID: chainId)
    }
}

public struct BlockchainParams {
    public let maxGasLimit: BigUInt
    public let minGasLimit: BigUInt

    public let maxPrice: BigUInt
    public let minPrice: BigUInt
    public let defaultPrice: BigUInt

    public let canUserChangeGas: Bool
    public let shouldAddBufferWhenEstimatingGasPrice: Bool

    public static func defaultParams(for server: RPCServer) -> BlockchainParams {
        return .init(
            maxGasLimit: GasLimitConfiguration.maxGasLimit(forServer: server),
            minGasLimit: GasLimitConfiguration.minGasLimit,
            maxPrice: GasPriceConfiguration.maxPrice(forServer: server),
            minPrice: GasPriceConfiguration.minPrice,
            defaultPrice: GasPriceConfiguration.defaultPrice(forServer: server),
            canUserChangeGas: server.canUserChangeGas,
            shouldAddBufferWhenEstimatingGasPrice: server.shouldAddBufferWhenEstimatingGasPrice)
    }
}

public final class RpcBlockchainProvider: BlockchainProvider {
    private let analytics: AnalyticsLogger
    private let nodeApiProvider: NodeApiProvider
    private lazy var getEventLogs = GetEventLogs(server: server)

    public let params: BlockchainParams
    public let server: RPCServer
    public let wallet: Wallet

    public init(server: RPCServer, account: Wallet, nodeApiProvider: NodeApiProvider, analytics: AnalyticsLogger, params: BlockchainParams) {
        self.analytics = analytics
        self.wallet = account
        self.server = server
        self.params = params
        self.nodeApiProvider = nodeApiProvider
    }

    //TODO: update it later
    public func eventLogsPromise(contractAddress: AlphaWallet.Address, eventName: String, abiString: String, filter: EventFilter) -> Promise<[EventParserResultProtocol]> {
        getEventLogs.getEventLogs(contractAddress: contractAddress, eventName: eventName, abiString: abiString, filter: filter)
    }

    public func blockByNumberPromise(blockNumber: BigUInt) -> Promise<Block> {
        return nodeApiProvider
            .dataTaskPromise(BlockByNumberRequest(number: blockNumber))
    }

    public func blockNumberPublisher() -> AnyPublisher<Int, SessionTaskError> {
        return nodeApiProvider
            .dataTaskPublisher(BlockNumberRequest())
            .print("xxx.blockNumber")
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    public func callPromise<R: ContractMethodCall>(_ method: R) -> Promise<R.Response> {
        nodeApiProvider
            .dataTaskPromise(method)
            .get {
                print("xxx.call value: \($0) for \(method.description)")
            }.recover { e -> Promise<R.Response> in
                print("xxx.call error: \(e) for \(method.description)")
                return .init(error: e)
            }
    }

    public func callPublisher<R: ContractMethodCall>(_ method: R) -> AnyPublisher<R.Response, SessionTaskError> {
        nodeApiProvider
            .dataTaskPublisher(method)
            .print("xxx.call")
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    //TODO: might be needed to handle of several call issue. applicatable for multiple rpc urls,
    //we applying inflight promises/publishers for rpc calls, but it could not work when balance is going to be fetched with another rpc url.
    public func balancePublisher(for address: AlphaWallet.Address) -> AnyPublisher<Balance, SessionTaskError> {
        return nodeApiProvider
            .dataTaskPublisher(BalanceRequest(address: address, block: .latest))
            .print("xxx.balancePublisher")
            .eraseToAnyPublisher()
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
            }.recover { e -> Promise<Int> in
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

    public func sendPublisher(transaction: UnsignedTransaction, data: Data) -> AnyPublisher<String, SessionTaskError> {
        return nodeApiProvider
            .dataTaskPublisher(SendRawTransactionRequest(signedTransaction: data.hexEncoded))
            .handleEvents(receiveOutput: {
                infoLog("Sent transaction with transactionId: \($0)")
            }, receiveCompletion: { [weak self] result in
                if case .failure(let error) = result {
                    self?.logSelectSendError(error)
                }
            }).receive(on: RunLoop.main)
            .eraseToAnyPublisher()
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
                    if limit == params.minGasLimit {
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
