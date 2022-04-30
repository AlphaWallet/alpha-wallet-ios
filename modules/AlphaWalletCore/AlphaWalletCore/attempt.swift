//
//  attempt.swift
//  AlphaWalletCore
//
//  Created by Hwee-Boon Yar on Apr/30/22.
//

import Foundation
import PromiseKit

public func attempt<T>(maximumRetryCount: Int = 3, delayBeforeRetry: DispatchTimeInterval = .seconds(1), delayUpperRangeValueFrom0To: Int = 5, _ body: @escaping () -> Promise<T>) -> Promise<T> {
    var attempts = 0
    func attempt() -> Promise<T> {
        attempts += 1
        return body().recover { error -> Promise<T> in
            guard attempts < maximumRetryCount else {
                throw error
            }

            if case PMKError.cancelled = error {
                throw error
            }
            return after(delayBeforeRetry.nextRandomInterval(upTo: delayUpperRangeValueFrom0To)).then(on: nil, attempt)
        }
    }

    return attempt()
}

fileprivate extension DispatchTimeInterval {
    func nextRandomInterval(upTo value: Int = 5) -> DispatchTimeInterval {
        let jitter = Int.random(in: 0 ..< value)

        switch self {
        case .microseconds(let value):
            return .microseconds(value + jitter)
        case .milliseconds(let value):
            return .milliseconds(value + jitter)
        case .nanoseconds(let value):
            return .nanoseconds(value + jitter)
        case .never:
            return .never
        case .seconds(let value):
            return .seconds(value + jitter)
        }
    }
}