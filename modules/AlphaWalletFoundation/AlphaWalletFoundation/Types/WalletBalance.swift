//
//  WalletBalance.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.05.2021.
//

import Foundation
import BigInt

public struct WalletBalance {
    private let etherToken: TokenViewModel?
    public let wallet: Wallet
    public let totalAmount: ValueForCurrency?
    public let change: ValueForCurrency?

    init(wallet: Wallet, tokens: [TokenViewModel]) {
        self.wallet = wallet

        if tokens.allSatisfy({ $0.server.isTestnet }) {
            if let server = tokens.map { $0.server }.sorted(by: { $0.displayOrderPriority > $1.displayOrderPriority }).first {
                etherToken = tokens.first(where: { $0 == MultipleChainsTokensDataStore.functional.etherToken(forServer: server) })
            } else {
                etherToken = nil
            }
        } else {
            etherToken = tokens.first(where: { $0 == MultipleChainsTokensDataStore.functional.etherToken(forServer: .main) })
        }
        self.totalAmount = WalletBalance.functional.createTotalAmount(for: tokens)
        self.change = WalletBalance.functional.createChange(for: tokens)
    }

    public var totalAmountString: String {
        if let totalAmount = totalAmount, let value = NumberFormatter.fiat(currency: totalAmount.currency).string(double: totalAmount.amount) {
            return value
        } else if let etherToken = etherToken, let amount = NumberFormatter.shortCrypto.string(double: etherToken.balance.valueDecimal.doubleValue) {
            return "\(amount) \(etherToken.tokenScriptOverrides?.symbolInPluralForm ?? etherToken.symbol)"
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

extension WalletBalance: Hashable {
    public static func == (lhs: WalletBalance, rhs: WalletBalance) -> Bool {
        return lhs.wallet.address.sameContract(as: rhs.wallet.address) && lhs.totalAmount == rhs.totalAmount && lhs.change == rhs.change
    }
}

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

    public static func createChange(for tokens: [TokenViewModel]) -> WalletBalance.ValueForCurrency? {
        var totalChange: Double?
        for token in tokens {
            guard let ticker = token.balance.ticker else { continue }
            if totalChange == nil { totalChange = 0.0 }

            if var totalChangePrev = totalChange {
                let balance = token.balance.valueDecimal.doubleValue * ticker.price_usd
                totalChangePrev += balance * ticker.percent_change_24h

                totalChange = totalChangePrev
            }
        }

        return validateAmount(amount: totalChange, tokens: tokens)
    }

    /// Returns validated amount, with checking all tokens satisfy condition of same currencies, in list
    private static func validateAmount(amount: Double?, tokens: [TokenViewModel]) -> WalletBalance.ValueForCurrency? {
        guard let amount = amount else { return nil }
        guard let ticker = tokens.first(where: { $0.balance.ticker != nil })?.balance.ticker else {
            //NOTE: we can't reach here if totalChange is nil
            return nil
        }

        return WalletBalance.ValueForCurrency(amount: amount, currency: ticker.currency)
    }

    public static func createTotalAmount(for tokens: [TokenViewModel]) -> WalletBalance.ValueForCurrency? {
        var totalAmount: Double?

        for token in tokens {
            guard let ticker = token.balance.ticker else { continue }

            if totalAmount == nil {
                totalAmount = 0.0
            }

            if var all = totalAmount {
                all += token.balance.valueDecimal.doubleValue * ticker.price_usd

                totalAmount = all
            }
        }

        return validateAmount(amount: totalAmount, tokens: tokens)
    }
}
