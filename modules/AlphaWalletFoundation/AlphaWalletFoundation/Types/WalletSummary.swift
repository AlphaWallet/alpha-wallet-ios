//
//  WalletSummary.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.05.2021.
//

import Foundation
import BigInt

public struct WalletSummary {
    private let totalAmount: WalletBalance.ValueForCurrency?
    public let changePercentage: WalletBalance.ValueForCurrency?

    public init(balances: [WalletBalance]) {
        self.changePercentage = functional.createChangePercentage(for: balances)
        self.totalAmount = functional.createTotalAmount(for: balances)
    }

    public var totalAmountString: String {
        guard let amount = totalAmount else { return "--" }
        let formatter = NumberFormatter.fiatShort(currency: amount.currency)

        return formatter.string(double: amount.amount) ?? "--"
    }

    public var change: WalletBalance.ValueForCurrency? {
        guard let amount = totalAmount, let changePercentage = changePercentage else { return nil }
        assert(amount.currency == changePercentage.currency, "currencies MUST match")

        guard let value = (amount.amount / 100 * changePercentage.amount).nilIfNan else { return nil }

        return WalletBalance.ValueForCurrency(amount: value, currency: amount.currency)
    }
}

extension WalletSummary: Hashable { }

public extension Double {
    var nilIfNan: Double? {
        guard !isNaN else { return nil }
        return self
    }
}

public extension Decimal {
    var nilIfNan: Decimal? {
        guard !isNaN else { return nil }
        return self
    }
}

extension WalletSummary {
    public enum functional {}
}

fileprivate extension WalletSummary.functional {
    static func createChangePercentage(for balances: [WalletBalance]) -> WalletBalance.ValueForCurrency? {
        let values = balances.compactMap { value -> WalletBalance.ValueForCurrency? in
            if let value = value.changePercentage {
                guard !value.amount.isNaN else { return nil }
                return WalletBalance.ValueForCurrency(amount: value.amount, currency: value.currency)
            } else {
                return nil
            }
        }

        return reduce(all: values)
    }

    static func createTotalAmount(for balances: [WalletBalance]) -> WalletBalance.ValueForCurrency? {
        let values = balances.compactMap { each -> WalletBalance.ValueForCurrency? in
            if let value = each.totalAmount {
                guard !value.amount.isNaN else { return nil }
                return WalletBalance.ValueForCurrency(amount: value.amount, currency: value.currency)
            } else {
                return nil
            }
        }

        return reduce(all: values)
    }

    //TODO: make tests
    static func reduce(all values: [WalletBalance.ValueForCurrency]) -> WalletBalance.ValueForCurrency? {
        guard !values.isEmpty else { return nil }

        let total = values.reduce(into: WalletBalance.ValueForCurrency(amount: 0, currency: .default)) { partialResult, each in
            partialResult.amount += each.amount
            partialResult.currency = each.currency
        }
        guard !total.amount.isNaN else { return nil }

        return total
    }
}
