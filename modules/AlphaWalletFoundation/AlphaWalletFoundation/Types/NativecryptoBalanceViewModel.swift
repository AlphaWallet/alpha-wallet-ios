//
//  NativecryptoBalanceViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.06.2021.
//

import Foundation
import BigInt

public struct NativecryptoBalanceViewModel: BalanceViewModelType {
    public var ticker: CoinTicker?
    private let token: BalanceRepresentable

    public init(token: BalanceRepresentable, ticker: CoinTicker?) {
        self.token = token
        self.ticker = ticker
    }
    public var balance: [TokenBalanceValue] { return [] }
    public var value: BigInt { token.valueBI }
    public var amount: Double { return EtherNumberFormatter.plain.string(from: token.valueBI, units: .ether).doubleValue }

    var amountString: String {
        guard !isZero else { return "0.00 \(token.server.symbol)" }
        let balance = EtherNumberFormatter.full.string(from: token.valueBI)
        return "\(balance) \(token.server.symbol)"
    }

    public var currencyAmount: String? {
        guard let totalAmount = currencyAmountWithoutSymbol else { return nil }
        return Formatter.usd.string(from: totalAmount)
    }

    public var currencyAmountWithoutSymbol: Double? {
        guard let currentRate = cryptoRate(forServer: token.server) else { return nil }
        return amount * currentRate.price
    }

    public var amountFull: String { return EtherNumberFormatter.plain.string(from: value) }
    public var amountShort: String { return EtherNumberFormatter.short.string(from: value) }
    public var symbol: String { return token.server.symbol }

    private func cryptoRate(forServer server: RPCServer) -> Rate? {
        guard let rate = ticker?.rate else { return nil }

        let code = mapSymbolToCodeInRates(server)
        let symbol = server.symbol.lowercased()
        if let value = rate.rates.first(where: { $0.code == code }) {
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
