//
//  Formatters.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 17/1/22.
//

import Foundation

public struct Formatter {

    public static let currency: NumberFormatter = {
        let formatter = basicCurrencyFormatter()
        formatter.minimumFractionDigits = Constants.formatterFractionDigits
        formatter.maximumFractionDigits = Constants.formatterFractionDigits
        formatter.currencySymbol = "$"
        return formatter
    }()

    public static let usd: NumberFormatter = {
        let formatter = basicCurrencyFormatter()
        formatter.positiveFormat = ",###.# " + Currency.USD.rawValue
        formatter.negativeFormat = "-,###.# " + Currency.USD.rawValue
        formatter.minimumFractionDigits = Constants.formatterFractionDigits
        formatter.maximumFractionDigits = Constants.formatterFractionDigits
        return formatter
    }()

    public static let percent: NumberFormatter = {
        let formatter = basicCurrencyFormatter()
        formatter.positiveFormat = ",###.#"
        formatter.negativeFormat = "-,###.#"
        formatter.minimumFractionDigits = Constants.formatterFractionDigits
        formatter.maximumFractionDigits = Constants.formatterFractionDigits
        formatter.numberStyle = .percent
        return formatter
    }()

    public static let shortCrypto: NumberFormatter = {
        let formatter = basicCurrencyFormatter()
        formatter.positiveFormat = ",###.#"
        formatter.negativeFormat = "-,###.#"
        formatter.minimumFractionDigits = Constants.etherFormatterFractionDigits
        formatter.maximumFractionDigits = Constants.etherFormatterFractionDigits
        formatter.numberStyle = .none
        return formatter
    }()

    public static let priceChange: NumberFormatter = {
        let formatter = basicCurrencyFormatter()
        formatter.positiveFormat = "+$,###.#"
        formatter.negativeFormat = "-$,###.#"
        formatter.minimumFractionDigits = Constants.formatterFractionDigits
        formatter.maximumFractionDigits = Constants.formatterFractionDigits
        return formatter
    }()

    public static let fiat: NumberFormatter = {
        let formatter = basicCurrencyFormatter()
        formatter.positiveFormat = "$,###.#"
        formatter.negativeFormat = "-$,###.#"
        formatter.minimumFractionDigits = Constants.formatterFractionDigits
        formatter.maximumFractionDigits = Constants.formatterFractionDigits
        return formatter
    }()

    public static let `default`: NumberFormatter = {
        let formatter = NumberFormatter()
        return formatter
    }()

    public static let scientificAmount: NumberFormatter = {
        let formatter = Formatter.default
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()

    public static let currencyAccounting: NumberFormatter = {
        let formatter = basicCurrencyFormatter()
        formatter.currencySymbol = ""
        formatter.minimumFractionDigits = Constants.formatterFractionDigits
        formatter.maximumFractionDigits = Constants.formatterFractionDigits
        formatter.numberStyle = .currencyAccounting
        formatter.isLenient = true
        return formatter
    }()

    public static let alternateAmount: NumberFormatter = {
        let formatter = basicCurrencyFormatter()
        formatter.currencySymbol = ""
        formatter.minimumFractionDigits = Constants.etherFormatterFractionDigits
        formatter.maximumFractionDigits = Constants.etherFormatterFractionDigits
        return formatter
    }()
}

fileprivate func basicCurrencyFormatter() -> NumberFormatter {
    let formatter = basicNumberFormatter()
    formatter.numberStyle = .currency
    formatter.roundingMode = .down
    return formatter
}

fileprivate func basicNumberFormatter() -> NumberFormatter {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.generatesDecimalNumbers = true
    formatter.alwaysShowsDecimalSeparator = true
    formatter.usesGroupingSeparator = true
    formatter.isLenient = false
    formatter.isPartialStringValidationEnabled = false
    formatter.groupingSeparator = ","
    formatter.decimalSeparator = "."
    return formatter
}

extension NumberFormatter {

    public func string(from source: Decimal) -> String? {
        return self.string(from: source as NSNumber)
    }

    public func string(from source: Double) -> String? {
        return self.string(from: source as NSNumber)
    }

    public func string(double: Double, minimumFractionDigits: Int, maximumFractionDigits: Int) -> String {
        let fractionDigits: Int
        
        let int = double.rounded(to: 0)
        let minimumFractionNumber = Double("0." + String(1).leftPadding(to: minimumFractionDigits, pad: "0"))!
        let maximumFractionNumber = Double("0." + String(1).leftPadding(to: maximumFractionDigits, pad: "0"))!

        if int >= 1 {
            fractionDigits = minimumFractionDigits
        } else if double == 0 {
            fractionDigits = 0
        } else if double <= maximumFractionNumber {
            fractionDigits = maximumFractionDigits
        } else if double <= minimumFractionNumber {
            fractionDigits = maximumFractionDigits
        } else {
            fractionDigits = minimumFractionDigits
        }

        self.maximumFractionDigits = fractionDigits
        self.minimumFractionDigits = fractionDigits

        if fractionDigits == minimumFractionDigits {
            return (self.string(from: double as NSNumber) ?? "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        } else {
            return (self.string(from: double as NSNumber) ?? "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).droppedTrailingZeros
        }
    }

}

fileprivate extension String {
    func leftPadding(to: Int, pad: String = " ") -> String {

        guard to > self.characters.count else { return self }

        let padding = String(repeating: pad, count: to - self.characters.count)
        return padding + self
    }
}
