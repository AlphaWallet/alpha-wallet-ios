// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

protocol BalanceBaseViewModel {
    var currencyAmount: String? { get }
    var amountFull: String { get }
    var amountShort: String { get }
    var symbol: String { get }
    var amount: Double { get }
    var currencyAmountWithoutSymbol: Double? { get }
    
    var value: BigInt { get }
    var ticker: CoinTicker? { get }
}

extension BalanceBaseViewModel {
    var isZero: Bool {
        value.isZero
    }

    var currencyRate: CurrencyRate? {
        ticker?.rate
    }
}
