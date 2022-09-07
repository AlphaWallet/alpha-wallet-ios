//
//  HistoryHelper.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.05.2022.
//

import Foundation

public struct HistoryHelper {

    public enum Change {
        case appreciate(percentage: Double, value: Double)
        case depreciate(percentage: Double, value: Double)
        case none
    }

    private let history: ChartHistory?

    public init(history: ChartHistory?) {
        self.history = history
    }

    public var minMax: (min: Double, max: Double)? {
        guard let history = history else { return nil }
        guard let min = history.prices.min(by: { $0.value < $1.value }), let max = history.prices.max(by: { $0.value < $1.value }) else { return nil }

        return (min.value, max.value)
    }

    public var change: HistoryHelper.Change {
        changeValues.flatMap { values -> HistoryHelper.Change in
            if isValueAppreciated24h(values.percentage) {
                return .appreciate(percentage: values.percentage, value: values.change)
            } else if isValueDepreciated24h(values.percentage) {
                return .depreciate(percentage: values.percentage, value: values.change)
            } else {
                return .none
            }
        } ?? .none
    }

    private var changeValues: (change: Double, percentage: Double)? {
        history.flatMap { history -> (Double, Double)? in
            let value = history.prices
            if value.isEmpty { return nil }

            var changeSum: Double = 0
            var percChangeSum: Double = 0
            for i in 0 ..< value.count - 1 {
                let change = value[i+1].value - value[i].value

                changeSum += change
                percChangeSum += change / value[i+1].value
            }
            return (changeSum, percChangeSum * 100)
        }
    }

    private func isValueAppreciated24h(_ value: Double?) -> Bool {
        if let percentChange = value {
            return percentChange > 0
        } else {
            return false
        }
    }

    private func isValueDepreciated24h(_ value: Double?) -> Bool {
        if let percentChange = value {
            return percentChange < 0
        } else {
            return false
        }
    }
}
