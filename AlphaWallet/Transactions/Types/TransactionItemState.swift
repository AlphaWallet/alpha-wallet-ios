// Copyright SIX DAY LLC. All rights reserved.

import Foundation

enum TransactionState: Int, CustomStringConvertible {
    case completed
    case pending
    case error
    case failed
    case unknown

    init(int: Int) {
        self = TransactionState(rawValue: int) ?? .unknown
    }

    var description: String {
        switch self {
        case .completed: return R.string.localizable.transactionStateCompleted()
        case .pending: return R.string.localizable.transactionStatePending()
        case .error: return R.string.localizable.transactionStateError()
        case .failed: return R.string.localizable.transactionStateFailed()
        case .unknown: return R.string.localizable.transactionStateUnknown()
        }
    }
}
