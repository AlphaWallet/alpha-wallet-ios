//
//  attempt.swift
//  AlphaWalletCore
//
//  Created by Hwee-Boon Yar on Apr/30/22.
//

import Foundation
import PromiseKit

public func attempt<T>(maximumRetryCount: Int = 3, delayBeforeRetry: DispatchTimeInterval = .seconds(1), delayUpperRangeValueFrom0To: Int = 5, shouldOnlyRetryIf: RetryPredicate? = nil, _ body: @escaping () -> Promise<T>) -> Promise<T> {
    var attempts = 0
    func attempt() -> Promise<T> {
        attempts += 1
        return body().recover { error -> Promise<T> in
            //NOTE: can't use guard here!!!
            if let shouldOnlyRetryIf = shouldOnlyRetryIf, !shouldOnlyRetryIf(error) { throw error }
            guard attempts < maximumRetryCount else { throw error }

            if case PMKError.cancelled = error {
                throw error
            }
            return after(.seconds(Int.random(in: 0 ..< delayUpperRangeValueFrom0To))).then(on: nil, attempt)
        }
    }

    return attempt()
}
