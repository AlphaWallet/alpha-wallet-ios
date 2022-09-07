//
//  Erc20BalanceViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.06.2021.
//

import Foundation
import BigInt
import AlphaWalletOpenSea

public protocol BalanceRepresentable {
    var balanceNft: [TokenBalanceValue] { get }
    var valueBI: BigInt { get }
    var type: TokenType { get }
    var decimals: Int { get }
    var symbol: String { get }
    var server: RPCServer { get }
}

public struct Erc20BalanceViewModel: BalanceViewModelType {
    private let token: BalanceRepresentable
    public var ticker: CoinTicker?

    init(token: BalanceRepresentable, ticker: CoinTicker?) {
        self.token = token
        self.ticker = ticker
    }

    public var balance: [TokenBalanceValue] { return [] }
    public var value: BigInt { token.valueBI }
    public var amount: Double { return EtherNumberFormatter.plain.string(from: token.valueBI).doubleValue }

    public var amountString: String {
        guard !isZero else { return "0.00 \(token.symbol)" }
        let balance = EtherNumberFormatter.plain.string(from: token.valueBI, decimals: token.decimals).droppedTrailingZeros
        return "\(balance) \(token.symbol)"
    }

    public var currencyAmount: String? {
        guard let totalAmount = currencyAmountWithoutSymbol else { return nil }
        return Formatter.usd.string(from: totalAmount)
    }

    public var currencyAmountWithoutSymbol: Double? {
        guard let currentRate = cryptoRate() else { return nil }
        return amount * currentRate.price
    }

    public var amountFull: String { return EtherNumberFormatter.plain.string(from: token.valueBI, decimals: token.decimals).droppedTrailingZeros }
    public var amountShort: String { return EtherNumberFormatter.short.string(from: token.valueBI, decimals: token.decimals).droppedTrailingZeros }
    public var symbol: String { return token.symbol }

    //NOTE: we suppose ticker.symbol is the same as token.symbol, for erc20 tokens
    private func cryptoRate() -> Rate? {
        guard let ticker = ticker else { return nil }
        let symbol = ticker.symbol.lowercased()
        if let value = ticker.rate.rates.first(where: { $0.code == symbol }) {
            return value
        } else {
            return nil
        }
    }

}
