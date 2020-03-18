// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

struct BalanceViewModel: BalanceBaseViewModel {
    private let server: RPCServer
    private let balance: Balance?
    private let rate: CurrencyRate?

    init(
        server: RPCServer,
        balance: Balance? = .none,
        rate: CurrencyRate? = .none
    ) {
        self.server = server
        self.balance = balance
        self.rate = rate
    }

    var amount: Double {
        guard let balance = balance else { return 0.00 }
        return CurrencyFormatter.plainFormatter.string(from: balance.value).doubleValue
    }

    var amountString: String {
        guard let balance = balance else { return "--" }
        guard !balance.isZero else { return "0.00 \(server.symbol)" }
        return "\(balance.amountFull) \(server.symbol)"
    }

    var currencyAmount: String? {
        guard let totalAmount = currencyAmountWithoutSymbol else { return nil }
        return CurrencyFormatter.formatter.string(from: NSNumber(value: totalAmount))
    }

    var currencyAmountWithoutSymbol: Double? {
        guard let rate = rate else { return nil }
        let symbol = mapSymbolToVersionInRates(server.symbol.lowercased())
        guard
                let currentRate = (rate.rates.filter { $0.code == symbol }.first),
                currentRate.price > 0,
                amount > 0
                else { return nil }
        return amount * currentRate.price
    }

    var amountFull: String {
        return balance?.amountFull ?? "--"
    }

    var amountShort: String {
        return balance?.amountShort ?? "--"
    }

    var symbol: String {
        return server.symbol
    }

    private func mapSymbolToVersionInRates(_ symbol: String) -> String {
        let mapping = ["xdai": "dai"]
        return mapping[symbol] ?? symbol
    }
}
