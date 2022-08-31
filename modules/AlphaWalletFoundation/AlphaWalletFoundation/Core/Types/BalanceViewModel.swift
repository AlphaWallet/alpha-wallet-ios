// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import AlphaWalletCore
import AlphaWalletOpenSea

public protocol BalanceViewModelType {
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
    public var isZero: Bool { value.isZero }
    public var valueDecimal: NSDecimalNumber? { amountFull.optionalDecimalValue }
}

public struct BalanceViewModel: BalanceViewModelType {
    public let currencyAmount: String?
    public let amountFull: String
    public let amountShort: String
    public let symbol: String
    public let amount: Double
    public let currencyAmountWithoutSymbol: Double?
    
    public let value: BigInt
    public let balance: [TokenBalanceValue]

    public let ticker: CoinTicker?
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
