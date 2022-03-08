//
//  WalletSummary.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.05.2021.
//

import Foundation
import BigInt

struct WalletSummary: Equatable {

    private let balances: [WalletBalance]

    init(balances: [WalletBalance]) {
        self.balances = balances
    }

    var totalAmount: String {
        if let amount = totalAmountDouble, let value = Formatter.fiat.string(from: amount) {
            return value
        } else if let amount = etherTotalAmountDouble, let value = Formatter.shortCrypto.string(from: amount.doubleValue) {
            return "\(value) \(RPCServer.main.symbol)"
        } else {
            return "--"
        }
    }

    var changeDouble: Double? {
        if let amount = totalAmountDouble, let value = changePercentage {
            return (amount / 100 * value).nilIfNan
        } else {
            return nil
        }
    }

    var changePercentage: Double? {
        let values = balances.compactMap { $0.changePercentage }
        if values.isEmpty {
            return nil
        } else {
            return values.reduce(0, +).nilIfNan
        }
    }

    private var totalAmountDouble: Double? {
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

    private var etherTotalAmountDouble: NSDecimalNumber? {
        var amount: NSDecimalNumber?

        for each in balances {
            if let eachEtherAmount = each.etherTokenObject?.valueDecimal {
                if amount == nil { amount = .zero }

                if let currentAmount = amount {
                    amount = currentAmount.adding(eachEtherAmount)
                }
            }
        }

        return amount
    }
}

extension Double {
    var nilIfNan: Double? {
        guard !isNaN else { return nil }
        return self
    }
}
