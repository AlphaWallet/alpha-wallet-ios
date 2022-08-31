//
//  WaitTillTransactionCompleted.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.08.2022.
//

import Foundation
import APIKit
import JSONRPCKit
import PromiseKit
import AlphaWalletCore

public final class WaitTillTransactionCompleted {
    private let server: RPCServer
    private let analytics: AnalyticsLogger
    private lazy var provider = GetIsTransactionCompleted(server: server, analytics: analytics)

    public init(server: RPCServer, analytics: AnalyticsLogger) {
        self.server = server
        self.analytics = analytics
    }

    public func waitTillCompleted(hash: EthereumTransaction.Hash, timesToRepeat: Int = 50) -> Promise<Void> {
        return attempt(maximumRetryCount: timesToRepeat, delayBeforeRetry: .seconds(10), delayUpperRangeValueFrom0To: 20) { [provider] in
            firstly {
                provider.getTransactionIfCompleted(hash: hash)
            }.map { _ in }
        }
    }
}
