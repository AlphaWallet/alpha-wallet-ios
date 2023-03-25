//
//  BlockNumberSchedulerProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.08.2022.
//

import Foundation
import Combine
import AlphaWalletCore
import CombineExt

public typealias BlockNumber = Int

public protocol BlockNumberSchedulerProviderDelegate: AnyObject {
    func didReceive(result: Result<BlockNumber, PromiseError>)
}

public final class BlockNumberSchedulerProvider: SchedulerProvider {
    private let blockchainProvider: BlockchainProvider

    var interval: TimeInterval { return Constants.BlockNumberProvider.getChainStateInterval }
    var name: String { "BlockNumberSchedulerProvider.\(blockchainProvider.server)" }

    var operation: AnyPublisher<Void, PromiseError> {
        blockchainProvider.blockNumber()
            .receive(on: RunLoop.main)
            .handleEvents(receiveOutput: { [weak self] response in
                self?.didReceiveValue(response: response)
            }, receiveCompletion: { [weak self] result in
                guard case .failure(let e) = result else { return }
                self?.didReceiveError(error: PromiseError(error: e))
            }).mapToVoid()
            .mapError { PromiseError(error: $0) }
            .eraseToAnyPublisher()
    }
    public weak var delegate: BlockNumberSchedulerProviderDelegate?

    public init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    private func didReceiveValue(response blockNumber: BlockNumber) {
        delegate?.didReceive(result: .success(blockNumber))
    }

    private func didReceiveError(error: PromiseError) {
        delegate?.didReceive(result: .failure(error))
    }
}
