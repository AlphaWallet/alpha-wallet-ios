//
//  WalletBalance.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.05.2021.
//

import Foundation
import BigInt
import AlphaWalletWeb3

public struct WalletBalance {
    fileprivate struct BalanceRepresentable: Hashable {
        let balance: Double
        let price: Double?
        let currency: Currency?
        let percentChange24: Double?
        let symbol: String

        init(token: TokenViewModel) {
            balance = token.balance.valueDecimal.doubleValue
            symbol = token.tokenScriptOverrides?.symbolInPluralForm ?? token.symbol
            price = token.balance.ticker?.price_usd
            currency = token.balance.ticker?.currency
            percentChange24 = token.balance.ticker?.percent_change_24h
        }
    }

    private let etherBalance: BalanceRepresentable?
    public let wallet: Wallet
    public let totalAmount: ValueForCurrency?
    public let change: ValueForCurrency?

    init(wallet: Wallet, tokens: [TokenViewModel], currency: Currency) {
        self.wallet = wallet

        if tokens.allSatisfy({ $0.server.isTestnet }) {
            if let server = tokens.map { $0.server }.sorted(by: { $0.displayOrderPriority > $1.displayOrderPriority }).first {
                etherBalance = tokens.first(where: { $0 == MultipleChainsTokensDataStore.functional.etherToken(forServer: server) })
                    .flatMap { BalanceRepresentable(token: $0) }
            } else {
                etherBalance = nil
            }
        } else {
            etherBalance = tokens.first(where: { $0 == MultipleChainsTokensDataStore.functional.etherToken(forServer: .main) })
                .flatMap { BalanceRepresentable(token: $0) }
        }

        let tokens = tokens.map { BalanceRepresentable(token: $0) }
        self.totalAmount = WalletBalance.functional.createTotalAmount(for: tokens, currency: currency)
        self.change = WalletBalance.functional.createChange(for: tokens, currency: currency)
    }

    public var totalAmountString: String {
        if let totalAmount = totalAmount, let value = NumberFormatter.fiat(currency: totalAmount.currency).string(double: totalAmount.amount) {
            return value
        } else if let balance = etherBalance, let amount = NumberFormatter.shortCrypto.string(double: balance.balance) {
            return "\(amount) \(balance.symbol)"
        } else {
            return "--"
        }
    }

    public var changePercentage: ValueForCurrency? {
        guard let change = change, let total = totalAmount else { return nil }

        return .init(amount: change.amount / total.amount, currency: total.currency)
    }

    public var changePercentageString: String {
        guard let changePercentage = changePercentage else { return "-" }
        let helper = TickerHelper(ticker: nil)
        let formatter = NumberFormatter.priceChange(currency: changePercentage.currency)

        switch helper.change24h(from: changePercentage.amount) {
        case .appreciate(let percentageChange24h):
            return "\(formatter.string(double: percentageChange24h) ?? "")%"
        case .depreciate(let percentageChange24h):
            return "\(formatter.string(double: percentageChange24h) ?? "")%"
        case .none:
            return "-"
        }
    }
}

extension Balance: CustomStringConvertible {
    public var description: String {
        return "value: \(EtherNumberFormatter.full.string(from: value))"
    }
}

extension WalletBalance: Hashable { }

public extension WalletBalance {
    public struct ValueForCurrency: Equatable, Hashable {
        public var amount: Double
        public var currency: Currency

        public init(amount: Double, currency: Currency) {
            self.amount = amount
            self.currency = currency
        }
    }

    public enum functional {}
}

extension WalletBalance.functional {

    fileprivate static func createChange(for tokens: [WalletBalance.BalanceRepresentable], currency: Currency) -> WalletBalance.ValueForCurrency? {
        var totalChange: Double? = 0.0
        for token in tokens {
            if totalChange == nil { totalChange = 0.0 }

            if var totalChangePrev = totalChange {
                let balance = token.balance * (token.price ?? 0)
                totalChangePrev += balance * (token.percentChange24 ?? 0)

                totalChange = totalChangePrev
            }
        }

        let currency = tokens.compactMap { $0.currency }.first ?? currency

        return totalChange.flatMap { WalletBalance.ValueForCurrency(amount: $0, currency: currency) }
    }

    fileprivate static func createTotalAmount(for tokens: [WalletBalance.BalanceRepresentable], currency: Currency) -> WalletBalance.ValueForCurrency? {
        var totalAmount: Double? = 0

        for token in tokens {

            if totalAmount == nil {
                totalAmount = 0.0
            }

            if var all = totalAmount {
                all += token.balance * (token.price ?? 0)

                totalAmount = all
            }
        }

        let currency = tokens.compactMap { $0.currency }.first ?? currency
        return totalAmount.flatMap { WalletBalance.ValueForCurrency(amount: $0, currency: currency) }
    }
}
