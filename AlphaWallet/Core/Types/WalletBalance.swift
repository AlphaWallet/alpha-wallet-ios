//
//  WalletBalance.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.05.2021.
//

import UIKit
import BigInt

struct WalletBalance: Equatable {
    private let tokensWithTickers: Set<Activity.AssignedToken>
    private let wallet: Wallet
    
    init(wallet: Wallet, values: Set<Activity.AssignedToken>) {
        self.wallet = wallet
        self.tokensWithTickers = values
    }

    var totalAmountString: String {
        if let totalAmount = totalAmountDouble, let value = NumberFormatter.usd.string(from: totalAmount) {
            return value
        } else if let etherAmount = etherAmountShort {
            return "\(etherAmount) \(RPCServer.main.symbol)"
        } else {
            return "--"
        }
    }

    var etherAmountShort: String? {
        guard let token = etherTokenObject, let value = token.valueDecimal else { return nil }

        return NumberFormatter.shortCrypto.string(from: value.doubleValue)
    }

    var etherTokenObject: Activity.AssignedToken? {
        let etherToken = TokensDataStore.etherToken(forServer: .main)
        guard let token = tokensWithTickers.first(where: { $0.primaryKey == etherToken.primaryKey }) else {
            return nil
        }
        
        return token
    }

    var changeDouble: Double? {
        var totalChange: Double?
        for each in tokensWithTickers {
            guard let value = each.valueDecimal, let ticker = each.ticker else { continue }
            if totalChange == nil { totalChange = 0.0 }

            if var totalChangePrev = totalChange {
                let balance = value.doubleValue * ticker.price_usd
                totalChangePrev += balance * ticker.percent_change_24h

                totalChange = totalChangePrev
            }
        }
        
        return totalChange
    }
    
    var changePercentage: Double? {
        if let change = changeDouble, let total = totalAmountDouble {
            return change / total
        } else {
            return nil
        }
    }

    var totalAmountDouble: Double? {
        var totalAmount: Double?

        for each in tokensWithTickers {
            guard let value = each.valueDecimal, let ticker = each.ticker else { continue }

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

    private var ticker: CoinTicker? {
        etherTokenObject?.ticker
    }

    var valuePercentageChangeValue: String {
        switch BalanceHelper().change24h(from: changePercentage) {
        case .appreciate(let percentageChange24h):
            return "+ \(percentageChange24h)%"
        case .depreciate(let percentageChange24h):
            return "\(percentageChange24h)%"
        case .none:
            return "-"
        }
    }

    var valuePercentageChangeColor: UIColor {
        return BalanceHelper().valueChangeValueColor(from: changeDouble)
    }
}

extension Balance: CustomStringConvertible {
    var description: String {
        return "value: \(amountFull)"
    }
}
