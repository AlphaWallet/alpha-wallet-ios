//
//  WalletBalance.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.05.2021.
//

import Foundation
import BigInt

public struct WalletBalance: Equatable {
    public static func == (lhs: WalletBalance, rhs: WalletBalance) -> Bool {
        return lhs.wallet.address.sameContract(as: rhs.wallet.address) &&
            lhs.totalAmountDouble == rhs.totalAmountDouble &&
            lhs.changeDouble == rhs.changeDouble
    }

    public let wallet: Wallet
    private let tokens: [TokenViewModel]
    public var totalAmountDouble: Double?
    public var changeDouble: Double?

    public init(wallet: Wallet, tokens: [TokenViewModel]) {
        self.wallet = wallet
        self.tokens = tokens
        self.totalAmountDouble = WalletBalance.functional.createTotalAmountDouble(tokens: tokens)
        self.changeDouble = WalletBalance.functional.createChangeDouble(tokens: tokens)
    }

    public var totalAmountString: String {
        if let totalAmount = totalAmountDouble, let value = Formatter.usd.string(from: totalAmount) {
            return value
        } else if let etherAmount = etherAmountShort {
            return "\(etherAmount) \(RPCServer.main.symbol)"
        } else {
            return "--"
        }
    }

    public var etherAmountShort: String? {
        guard let token = etherToken, let value = token.valueDecimal else { return nil }

        return Formatter.shortCrypto.string(from: value.doubleValue)
    }

    public var etherToken: TokenViewModel? {
        let etherToken: TokenViewModel = .init(token: MultipleChainsTokensDataStore.functional.etherToken(forServer: .main))
        guard let token = tokens.first(where: { $0 == etherToken }) else {
            return nil
        }

        return token
    }
    
    public var changePercentage: Double? {
        if let change = changeDouble, let total = totalAmountDouble {
            return change / total
        } else {
            return nil
        }
    }
    
    public var valuePercentageChangeValue: String {
        switch BalanceHelper().change24h(from: changePercentage) {
        case .appreciate(let percentageChange24h):
            return "+ \(percentageChange24h)%"
        case .depreciate(let percentageChange24h):
            return "\(percentageChange24h)%"
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
