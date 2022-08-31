//
//  WalletSummary.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.05.2021.
//

import Foundation
import BigInt

public struct WalletSummary {
    private var totalAmountDouble: Double?
    private var etherTotalAmountDouble: NSDecimalNumber?

    public let changePercentage: Double?

    public init(balances: [WalletBalance]) {
        self.changePercentage = WalletSummary.functional.createChangePercentage(balances: balances)
        self.totalAmountDouble = WalletSummary.functional.createTotalAmount(balances: balances)
        self.etherTotalAmountDouble = WalletSummary.functional.createEtherTotalAmountDouble(balances: balances)
    }

    public var totalAmount: String {
        if let amount = totalAmountDouble, let value = Formatter.fiat.string(from: amount) {
            return value
        } else if let amount = etherTotalAmountDouble, let value = Formatter.shortCrypto.string(from: amount.doubleValue) {
            return "\(value) \(RPCServer.main.symbol)"
        } else {
            return "--"
        }
    }

    public var changeDouble: Double? {
        if let amount = totalAmountDouble, let value = changePercentage {
            return (amount / 100 * value).nilIfNan
        } else {
            return nil
        }
    }
}

extension WalletSummary: Hashable { }

public extension Double {
    var nilIfNan: Double? {
        guard !isNaN else { return nil }
        return self
    }
}

public extension WalletSummary {
    public enum functional {}
}

extension WalletSummary.functional {

    public static func createChangePercentage(balances: [WalletBalance]) -> Double? {
        let values = balances.compactMap { $0.changePercentage?.nilIfNan }
        if values.isEmpty {
            return nil
        } else {
            return values.reduce(0, +).nilIfNan
        }
    }

    public static func createTotalAmount(balances: [WalletBalance]) -> Double? {
        var amount: Double?

        for each in balances {
            if let eachTotalAmount = each.totalAmountDouble {
                if amount == nil { amount = .zero }

                if let currentAmount = amount {
                    amount = currentAmount + eachTotalAmount
                }
            }
        }

        return amount?.nilIfNan
    }

    public static func createEtherTotalAmountDouble(balances: [WalletBalance]) -> NSDecimalNumber? {
        var amount: NSDecimalNumber?

        for each in balances {
            if let eachEtherAmount = each.etherToken?.valueDecimal {
                if amount == nil { amount = .zero }

                if let currentAmount = amount {
                    amount = currentAmount.adding(eachEtherAmount)
                }
            }
        }

        return amount
    }
}
