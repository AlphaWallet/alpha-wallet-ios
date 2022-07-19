//
//  WalletBalance.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.05.2021.
//

import UIKit
import BigInt

struct WalletBalance: Equatable {
    static func == (lhs: WalletBalance, rhs: WalletBalance) -> Bool {
        return lhs.wallet.address.sameContract(as: rhs.wallet.address) &&
            lhs.totalAmountDouble == rhs.totalAmountDouble &&
            lhs.changeDouble == rhs.changeDouble
    }

    private let wallet: Wallet
    private let tokens: [Token]
    var totalAmountDouble: Double?
    var changeDouble: Double?

    init(wallet: Wallet, tokens: [Token], coinTickersFetcher: CoinTickersFetcher) {
        self.wallet = wallet
        self.tokens = tokens
        self.totalAmountDouble = WalletBalance.functional.createTotalAmountDouble(tokens: tokens, coinTickersFetcher: coinTickersFetcher)
        self.changeDouble = WalletBalance.functional.createChangeDouble(tokens: tokens, coinTickersFetcher: coinTickersFetcher)
    }

    var totalAmountString: String {
        if let totalAmount = totalAmountDouble, let value = Formatter.usd.string(from: totalAmount) {
            return value
        } else if let etherAmount = etherAmountShort {
            return "\(etherAmount) \(RPCServer.main.symbol)"
        } else {
            return "--"
        }
    }

    var etherAmountShort: String? {
        guard let token = etherToken, let value = token.valueDecimal else { return nil }

        return Formatter.shortCrypto.string(from: value.doubleValue)
    }

    var etherToken: Token? {
        let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: .main)
        guard let token = tokens.first(where: { $0.primaryKey == etherToken.primaryKey }) else {
            return nil
        }
        
        return token
    }
    
    var changePercentage: Double? {
        if let change = changeDouble, let total = totalAmountDouble {
            return change / total
        } else {
            return nil
        }
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
        return "value: \(EtherNumberFormatter.full.string(from: value))"
    }
}

extension WalletBalance {
    enum functional {}
}

extension WalletBalance.functional {

    static func createChangeDouble(tokens: [Token], coinTickersFetcher: CoinTickersFetcher) -> Double? {
        var totalChange: Double?
        for each in tokens {
            guard let value = each.valueDecimal, let ticker = coinTickersFetcher.ticker(for: each.addressAndRPCServer) else { continue }
            if totalChange == nil { totalChange = 0.0 }

            if var totalChangePrev = totalChange {
                let balance = value.doubleValue * ticker.price_usd
                totalChangePrev += balance * ticker.percent_change_24h

                totalChange = totalChangePrev
            }
        }

        return totalChange
    }

    static func createTotalAmountDouble(tokens: [Token], coinTickersFetcher: CoinTickersFetcher) -> Double? {
        var totalAmount: Double?

        for each in tokens {
            guard let value = each.valueDecimal, let ticker = coinTickersFetcher.ticker(for: each.addressAndRPCServer) else { continue }

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
