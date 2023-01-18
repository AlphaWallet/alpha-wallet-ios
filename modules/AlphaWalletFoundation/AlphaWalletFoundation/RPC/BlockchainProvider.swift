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
    func pendingTransaction(hash: String) -> AnyPublisher<PendingTransaction?, SessionTaskError>
    func block(by blockNumber: BigUInt) -> AnyPublisher<Date, SessionTaskError>
    func eventLogs(contractAddress: AlphaWallet.Address, eventName: String, abiString: String, filter: EventFilter) -> AnyPublisher<[EventParserResultProtocol], SessionTaskError>
}

public final class RpcBlockchainProvider: BlockchainProvider {
    private let getPendingTransaction: GetPendingTransaction
    private let getEventLogs: GetEventLogs
    private let analytics: AnalyticsLogger
    private lazy var getBlockTimestamp = GetBlockTimestamp(analytics: analytics)
    private lazy var getBlockNumber = GetBlockNumber(server: server, analytics: analytics)

    public let server: RPCServer

    public init(server: RPCServer,
                analytics: AnalyticsLogger) {

        self.analytics = analytics
        self.server = server
        self.getEventLogs = GetEventLogs()
        self.getPendingTransaction = GetPendingTransaction(server: server, analytics: analytics)
    }

    public func blockNumber() -> AnyPublisher<Int, SessionTaskError> {
        getBlockNumber.getBlockNumber()
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

}
