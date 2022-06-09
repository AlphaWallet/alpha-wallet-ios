//
//  Erc20BalanceViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.06.2021.
//

import Foundation
import BigInt

struct Erc20BalanceViewModel: BalanceViewModel {
    private let token: Token
    private (set) var ticker: CoinTicker?

    init(token: Token, ticker: CoinTicker?) {
        self.token = token
        self.ticker = ticker
    }

    var value: BigInt { token.value }
    var amount: Double { return EtherNumberFormatter.plain.string(from: token.value).doubleValue }

    var amountString: String {
        guard !isZero else { return "0.00 \(token.symbol)" }
        let balance = EtherNumberFormatter.plain.string(from: token.value, decimals: token.decimals).droppedTrailingZeros
        return "\(balance) \(token.symbol)"
    }

    var currencyAmount: String? {
        guard let totalAmount = currencyAmountWithoutSymbol else { return nil }
        return Formatter.usd.string(from: totalAmount)
    }

    var currencyAmountWithoutSymbol: Double? {
        guard let currentRate = cryptoRate(forToken: token) else { return nil }
        return amount * currentRate.price
    }

    var amountFull: String { return EtherNumberFormatter.plain.string(from: token.value, decimals: token.decimals).droppedTrailingZeros }
    var amountShort: String { return EtherNumberFormatter.short.string(from: token.value, decimals: token.decimals).droppedTrailingZeros }
    var symbol: String { return token.symbol }

    //NOTE: we suppose ticker.symbol is the same as token.symbol, for erc20 tokens
    private func cryptoRate(forToken token: Token) -> Rate? {
        guard let ticker = ticker else { return nil }
        let symbol = ticker.symbol.lowercased()
        if let value = ticker.rate.rates.first(where: { $0.code == symbol }) {
            return value
        } else {
            return nil
        }
    }

}
