//
//  ChainStateSchedulerProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.08.2022.
//

import Foundation
import Combine
import AlphaWalletCore

public protocol ChainStateSchedulerProviderDelegate: AnyObject {
    func didReceive(result: Result<Int, PromiseError>)
}

public final class ChainStateSchedulerProvider: SchedulerProvider {
    private let server: RPCServer
    private let analytics: AnalyticsLogger
    private lazy var blockNumberProvider = GetBlockNumber(server: server, analytics: analytics)

    var interval: TimeInterval { return Constants.ChainState.getChainStateInterval }
    var name: String { "ChainStateSchedulerProvider" }
    var operation: AnyPublisher<Void, SchedulerError> {
        blockNumberProvider.getBlockNumber().publisher
            .handleEvents(receiveOutput: { [weak self] response in
                self?.didReceiveValue(response: response)
            }, receiveCompletion: { [weak self] result in
                guard case .failure(let e) = result else { return }
                self?.didReceiveError(error: e)
            }).mapToVoid()
            .mapError { SchedulerError.promiseError($0) }
            .eraseToAnyPublisher()
    }
    public weak var delegate: ChainStateSchedulerProviderDelegate?

    public init(server: RPCServer, analytics: AnalyticsLogger) {
        self.server = server
        self.analytics = analytics
    }

    private func didReceiveValue(response block: Int) {
        delegate?.didReceive(result: .success(block))
    }

    private func didReceiveError(error: PromiseError) {
        delegate?.didReceive(result: .failure(error))
    }
}
