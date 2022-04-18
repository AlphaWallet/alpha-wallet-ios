//
//  NativecryptoBalanceViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.06.2021.
//

import Foundation
import BigInt

struct NativecryptoBalanceViewModel: BalanceBaseViewModel {

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
        return EtherNumberFormatter.plain.string(from: balance.value, units: .ether).doubleValue
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

extension BalanceBaseViewModel {
    func cryptoRate(forServer server: RPCServer) -> Rate? {
        guard let rate = ticker?.rate else { return nil }
        
        let code = mapSymbolToCodeInRates(server)
        let symbol = server.symbol.lowercased()
        if let value = rate.rates.first(where: { $0.code == code }) {
            return value
        } else if let value = rate.rates.first(where: { $0.code == "gno" }), server == .xDai {
            return value
        } else if let value = rate.rates.first(where: { $0.code == symbol }) {
            return value
        } else {
            return nil
        }
    }

    private func mapSymbolToCodeInRates(_ server: RPCServer) -> String {
        let symbol = server.symbol.lowercased()
        let mapping = ["xdai": "dai", "aeth": "eth"]

        return mapping[symbol] ?? symbol
    }
}
