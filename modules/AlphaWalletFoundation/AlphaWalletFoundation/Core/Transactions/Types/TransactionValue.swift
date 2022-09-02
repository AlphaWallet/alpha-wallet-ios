// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public struct TransactionValue {
    public let amount: String
    public let symbol: String

    public init(amount: String, symbol: String) {
        self.amount = amount
        self.symbol = symbol
    }
}
