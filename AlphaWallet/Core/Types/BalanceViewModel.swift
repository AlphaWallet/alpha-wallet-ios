// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

protocol BalanceViewModel {
    var currencyAmount: String? { get }
    var amountFull: String { get }
    var amountShort: String { get }
    var symbol: String { get }
    var amount: Double { get }
    var currencyAmountWithoutSymbol: Double? { get }
    
    var value: BigInt { get }
    var ticker: CoinTicker? { get }
}

extension BalanceViewModel {
    var isZero: Bool { value.isZero }
}
