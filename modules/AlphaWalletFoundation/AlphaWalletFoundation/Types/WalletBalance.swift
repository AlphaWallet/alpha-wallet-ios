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
    public let totalAmountDouble: Double?
    public let changeDouble: Double?
    public var etherBalance: NSDecimalNumber? {
        etherToken?.valueDecimal
    }

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
        self.totalAmountDouble = WalletBalance.functional.createTotalAmountDouble(tokens: tokens)
        self.changeDouble = WalletBalance.functional.createChangeDouble(tokens: tokens)
    }

    public var totalAmountString: String {
        if let totalAmount = totalAmountDouble, let value = Formatter.usd.string(from: totalAmount) {
            return value
        } else if let etherAmount = etherAmountShort, let token = etherToken {
            return "\(etherAmount) \(token.tokenScriptOverrides?.symbolInPluralForm ?? token.symbol)"
        } else {
            return "--"
        }
    }

    var etherAmountShort: String? {
        return etherToken?.valueDecimal.flatMap { Formatter.shortCrypto.string(from: $0.doubleValue) }
    }

    public var changePercentage: Double? {
        if let change = changeDouble, let total = totalAmountDouble {
            return change / total
        } else {
            return nil
        }
    }
    
    public var valuePercentageChangeValue: String {
        EthCurrencyHelper(ticker: nil).change24h(from: changePercentage).string ?? "-"
    }
}

extension Balance: CustomStringConvertible {
    public var description: String {
        return "value: \(EtherNumberFormatter.full.string(from: value))"
    }
}

extension WalletBalance: Hashable {
    public static func == (lhs: WalletBalance, rhs: WalletBalance) -> Bool {
        return lhs.wallet.address.sameContract(as: rhs.wallet.address) &&
            lhs.totalAmountDouble == rhs.totalAmountDouble &&
            lhs.changeDouble == rhs.changeDouble
    }
}

public extension WalletBalance {
    enum functional {}
}

extension WalletBalance.functional {

    public static func createChangeDouble(tokens: [TokenViewModel]) -> Double? {
        var totalChange: Double?
        for token in tokens {
            guard let value = token.balance.valueDecimal, let ticker = token.balance.ticker else { continue }
            if totalChange == nil { totalChange = 0.0 }

            if var totalChangePrev = totalChange {
                let balance = value.doubleValue * ticker.price_usd
                totalChangePrev += balance * ticker.percent_change_24h

                totalChange = totalChangePrev
            }
        }

        return totalChange
    }

    public static func createTotalAmountDouble(tokens: [TokenViewModel]) -> Double? {
        var totalAmount: Double?

        for token in tokens {
            guard let value = token.valueDecimal, let ticker = token.balance.ticker else { continue }

            if totalAmount == nil {
                totalAmount = 0.0
            }

            if var all = totalAmount {
                all += value.doubleValue * ticker.price_usd

                totalAmount = all
            }
        }

        return totalAmount
    }
}
