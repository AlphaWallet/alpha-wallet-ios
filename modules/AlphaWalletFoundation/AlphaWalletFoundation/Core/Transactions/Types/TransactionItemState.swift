// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public enum TransactionState: Int {
    case completed
    case pending
    case error
    case failed
    case unknown

    public init(int: Int) {
        self = TransactionState(rawValue: int) ?? .unknown
    }
}
