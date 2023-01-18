//
//  BlockchainProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 18.01.2023.
//

import Foundation
import Combine
import AlphaWalletWeb3
import BigInt

public protocol BlockchainProvider {
    var server: RPCServer { get }

    func blockNumber() -> AnyPublisher<Int, SessionTaskError>
    func transactionsState(hash: String) -> AnyPublisher<TransactionState, SessionTaskError>
    func call(from: AlphaWallet.Address?, to: AlphaWallet.Address?, value: String?, data: String) -> AnyPublisher<String, SessionTaskError>
    func call<R: ContractMethodCall>(_ method: R, block: BlockParameter) -> AnyPublisher<R.Response, SessionTaskError>
    func pendingTransaction(hash: String) -> AnyPublisher<PendingTransaction?, SessionTaskError>
    func nextNonce(wallet: AlphaWallet.Address) -> AnyPublisher<Int, SessionTaskError>
    func block(by blockNumber: BigUInt) -> AnyPublisher<Date, SessionTaskError>
    func eventLogs(contractAddress: AlphaWallet.Address, eventName: String, abiString: String, filter: EventFilter) -> AnyPublisher<[EventParserResultProtocol], SessionTaskError>
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

    public let server: RPCServer

    public init(server: RPCServer,
                analytics: AnalyticsLogger) {

        self.analytics = analytics
        self.server = server
        self.getEventLogs = GetEventLogs()
        self.getPendingTransaction = GetPendingTransaction(server: server, analytics: analytics)
    }

    public func call(from: AlphaWallet.Address?, to: AlphaWallet.Address?, value: String?, data: String) -> AnyPublisher<String, SessionTaskError> {
        let request = EthCall(server: server, analytics: analytics)
        return request.ethCall(from: from, to: to, value: value, data: data)
            .publisher(queue: .main)
            .mapError { SessionTaskError.responseError($0.embedded) }
            .eraseToAnyPublisher()
    }

    public func call<R: ContractMethodCall>(_ method: R, block: BlockParameter) -> AnyPublisher<R.Response, SessionTaskError> {
        callSmartContract(withServer: server, contract: method.contract, functionName: method.name, abiString: method.abi, parameters: method.parameters)
            .map { try method.response(from: $0) }
            .publisher(queue: .global())
            .mapError { SessionTaskError.responseError($0.embedded) }
            .eraseToAnyPublisher()
    }

    public func blockNumber() -> AnyPublisher<Int, SessionTaskError> {
        getBlockNumber.getBlockNumber()
            .publisher(queue: .global())
            .mapError { SessionTaskError.responseError($0.embedded) }
            .eraseToAnyPublisher()
    }

    public func transactionsState(hash: String) -> AnyPublisher<TransactionState, SessionTaskError> {
        getTransactionState
            .getTransactionsState(hash: hash)
            .publisher(queue: .global())
            .mapError { SessionTaskError.responseError($0.embedded) }
            .eraseToAnyPublisher()
    }

    public func pendingTransaction(hash: String) -> AnyPublisher<PendingTransaction?, SessionTaskError> {
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
            .publisher(queue: .global())
            .mapError { SessionTaskError.responseError($0.embedded) }
            .eraseToAnyPublisher()
    }

    public func nextNonce(wallet: AlphaWallet.Address) -> AnyPublisher<Int, SessionTaskError> {
        getNextNonce.getNextNonce(wallet: wallet)
            .publisher(queue: .global())
            .mapError { SessionTaskError.responseError($0.embedded) }
            .eraseToAnyPublisher()
    }

}
