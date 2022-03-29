//
//  ERC20BalanceViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.06.2021.
//

import Foundation
import BigInt

struct ERC20BalanceViewModel: BalanceBaseViewModel {

    var isZero: Bool {
        balance.value.isZero
    }

    private let server: RPCServer
    private let balance: BalanceProtocol
    private (set) var ticker: CoinTicker?

    init(server: RPCServer, balance: BalanceProtocol, ticker: CoinTicker?) {
        self.server = server
        self.balance = balance
        self.ticker = ticker
    }

    var value: BigInt {
        balance.value
    }

    var amount: Double {
        return EtherNumberFormatter.plain.string(from: balance.value).doubleValue
    }

    var amountString: String {
        guard !isZero else { return "0.00 \(server.symbol)" }
        return "\(balance.amountFull) \(server.symbol)"
    }

    var currencyAmount: String? {
        guard let totalAmount = currencyAmountWithoutSymbol else { return nil }
        return Formatter.usd.string(from: totalAmount)
    }

    var currencyAmountWithoutSymbol: Double? {
        guard let currentRate = cryptoRate(forServer: server) else { return nil }
        return amount * currentRate.price
    }

    var amountFull: String {
        return balance.amountFull
    }

    var amountShort: String {
        return balance.amountShort
    }

    var symbol: String {
        return server.symbol
    } 
}
