//
//  WaitTillTransactionCompleted.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.08.2022.
//

import Foundation
import PromiseKit
import AlphaWalletCore
import Combine

//TODO: improve waiting for tx completion
public final class WaitTillTransactionCompleted {
    struct NotCompletedYetError: Error { }

    private let blockchainProvider: BlockchainProvider

    public init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    public func waitTillCompleted(hash: String, timesToRepeat: Int = 50) -> AnyPublisher<Void, PromiseError> {
        Just(hash)
            .setFailureType(to: PromiseError.self)
            .flatMap { hash -> AnyPublisher<Void, PromiseError> in
                self.waitTillCompleted(hash: hash)
                    .retry(.randomDelayed(retries: UInt(timesToRepeat), delayBeforeRetry: 10, delayUpperRangeValueFrom0To: 20), scheduler: RunLoop.main)
                    .mapToVoid()
                    .eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }

    private func getTransactionIfCompleted(hash: String) -> AnyPublisher<PendingTransaction, PromiseError> {
        return blockchainProvider
            .pendingTransaction(hash: hash)
            .mapError { PromiseError(error: $0) }
            .flatMap { pendingTransaction -> AnyPublisher<PendingTransaction, PromiseError> in
                if let pendingTransaction = pendingTransaction, let blockNumber = Int(pendingTransaction.blockNumber), blockNumber > 0 {
                    return .just(pendingTransaction)
                } else {
                    return .fail(PromiseError(error: NotCompletedYetError()))
                }
            }.print("xxx.getTransactionIfCompleted")
            .eraseToAnyPublisher()
    }
}
