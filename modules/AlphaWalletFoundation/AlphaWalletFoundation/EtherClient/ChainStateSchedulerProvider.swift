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

//TODO move and use more, including in RpcBlockchainProvider and BlockNumberRequest
public typealias BlockNumber = Int

public final class BlockNumberSchedulerProvider: SchedulerProvider {
    private let blockchainProvider: BlockchainProvider
    private let subject = PassthroughSubject<Result<BlockNumber, PromiseError>, Never>()

    var interval: TimeInterval { return Constants.BlockNumberProvider.getChainStateInterval }
    var name: String { "BlockNumberSchedulerProvider.\(blockchainProvider.server)" }

    var operation: AnyPublisher<Void, PromiseError> {
        blockchainProvider.blockNumber()
            .receive(on: RunLoop.main)
            .handleEvents(receiveOutput: { [subject] response in
                subject.send(.success(response))
            }, receiveCompletion: { [subject] result in
                guard case .failure(let e) = result else { return }
                subject.send(.failure(PromiseError(error: e)))
            }).mapToVoid()
            .mapError { PromiseError(error: $0) }
            .eraseToAnyPublisher()
    }

    var publisher: AnyPublisher<Result<BlockNumber, PromiseError>, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }
}
