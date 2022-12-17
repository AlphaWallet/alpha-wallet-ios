//
//  WaitTillTransactionCompleted.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.08.2022.
//

import Foundation
import PromiseKit
import AlphaWalletCore

public final class WaitTillTransactionCompleted {
    private let blockchainProvider: BlockchainProvider

    public init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    public func waitTillCompleted(hash: EthereumTransaction.Hash, timesToRepeat: Int = 50) -> Promise<Void> {
        return attempt(maximumRetryCount: timesToRepeat, delayBeforeRetry: .seconds(10), delayUpperRangeValueFrom0To: 20) { [blockchainProvider] in
            firstly {
                blockchainProvider.getTransactionIfCompleted(hash: hash)
            }.map { _ in }
        }
    }
}
