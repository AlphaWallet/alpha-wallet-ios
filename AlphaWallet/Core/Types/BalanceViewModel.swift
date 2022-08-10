// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import AlphaWalletCore
import AlphaWalletOpenSea

protocol BalanceViewModelType {
    var currencyAmount: String? { get }
    var amountFull: String { get }
    var amountShort: String { get }
    var symbol: String { get }
    var amount: Double { get }
    var currencyAmountWithoutSymbol: Double? { get }

    var value: BigInt { get }
    var balance: [TokenBalanceValue] { get }

    var ticker: CoinTicker? { get }
}

extension BalanceViewModelType {
    var isZero: Bool { value.isZero }
    var valueDecimal: NSDecimalNumber? { amountFull.optionalDecimalValue }
}

struct BalanceViewModel: BalanceViewModelType {
    let currencyAmount: String?
    let amountFull: String
    let amountShort: String
    let symbol: String
    let amount: Double
    let currencyAmountWithoutSymbol: Double?
    
    let value: BigInt
    let balance: [TokenBalanceValue]

    let ticker: CoinTicker?
}

extension BalanceViewModel: Hashable { }

extension BalanceViewModel {
    init(balance: BalanceViewModelType) {
        self.currencyAmount = balance.currencyAmount
        self.amountFull = balance.amountFull
        self.amountShort = balance.amountShort
        self.symbol = balance.symbol
        self.amount = balance.amount
        self.currencyAmountWithoutSymbol = balance.currencyAmountWithoutSymbol
        self.value = balance.value
        self.balance = balance.balance
        self.ticker = balance.ticker
    }
}
