// Copyright SIX DAY LLC. All rights reserved.

import AlphaWalletWeb3
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

    public init(status: TransactionReceipt.TXStatus) {
        switch status {
        case .ok:
            self = .completed
        case .failed:
            self = .failed
        case .notYetProcessed:
            self = .pending
        }
    }
}
