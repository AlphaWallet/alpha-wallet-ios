//
//  Formatters.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 17/1/22.
//

import Foundation

extension NumberFormatter {

    public static func fiat(currency: Currency) -> NumberFormatter {
        let formatter = basicCurrencyFormatter()
        formatter.positiveFormat = ",###.# " + currency.rawValue
        formatter.negativeFormat = "-,###.# " + currency.rawValue
        formatter.minimumFractionDigits = Constants.formatterFractionDigits
        formatter.maximumFractionDigits = Constants.formatterFractionDigits

        return formatter
    }

    public static func fiatShort(currency: Currency) -> NumberFormatter {
        let formatter = basicCurrencyFormatter()
        formatter.positiveFormat = "\(currency.symbol),###.#"
        formatter.negativeFormat = "-\(currency.symbol),###.#"
        formatter.minimumFractionDigits = Constants.formatterFractionDigits
        formatter.maximumFractionDigits = Constants.formatterFractionDigits

        return formatter
    }

    public static var percent: NumberFormatter {
        let formatter = basicCurrencyFormatter()
        formatter.positiveFormat = ",###.#"
        formatter.negativeFormat = "-,###.#"
        formatter.minimumFractionDigits = Constants.formatterFractionDigits
        formatter.maximumFractionDigits = Constants.formatterFractionDigits
        formatter.numberStyle = .percent

        return formatter
    }

    //NOTE: doesn't work when its stored static let, should be computed var
    public static var shortCrypto: NumberFormatter {
        let formatter = basicCurrencyFormatter()
        formatter.positiveFormat = ",###.#"
        formatter.negativeFormat = "-,###.#"
        formatter.minimumFractionDigits = Constants.etherFormatterFractionDigits
        formatter.maximumFractionDigits = Constants.etherFormatterFractionDigits

        return formatter
    }

    public static func value(fractionDigits: Int = 0) -> NumberFormatter {
        let formatter = basicCurrencyFormatter()
        formatter.positiveFormat = ",###.#"
        formatter.negativeFormat = "-,###.#"
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits

        return formatter
    }

    public static func priceChange(currency: Currency) -> NumberFormatter {
        let formatter = basicCurrencyFormatter()
        formatter.currencyCode = currency.code
        formatter.positiveFormat = "+\(currency.symbol),###.#"
        formatter.negativeFormat = "-\(currency.symbol),###.#"
        formatter.minimumFractionDigits = Constants.formatterFractionDigits
        formatter.maximumFractionDigits = Constants.formatterFractionDigits

        return formatter
    }

    public static var scientificAmount: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.locale = Locale(identifier: "en_US")

        return formatter
    }

    public static var currencyAccounting: NumberFormatter {
        let formatter = basicCurrencyFormatter()
        formatter.currencySymbol = ""
        formatter.minimumFractionDigits = Constants.formatterFractionDigits
        formatter.maximumFractionDigits = Constants.formatterFractionDigits
        formatter.numberStyle = .currencyAccounting
        formatter.isLenient = true

        return formatter
    }
    //NOTE: don't use static let, some on formatters has changed in runtime, that brakes logic, use computed var
    public static var alternateAmount: NumberFormatter {
        let formatter = basicCurrencyFormatter()
        formatter.currencySymbol = ""
        formatter.minimumFractionDigits = Constants.etherFormatterFractionDigits
        formatter.maximumFractionDigits = Constants.etherFormatterFractionDigits

        return formatter
    }
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

    public func string(decimal source: Decimal) -> String? {
        return self.string(from: source as NSNumber)?.trimmed
    }

    public func string(double source: Double) -> String? {
        return self.string(from: source as NSNumber)?.trimmed
    }

    public func string(double: Double, minimumFractionDigits: Int, maximumFractionDigits: Int) -> String {
        let fractionDigits: Int

        let int = double.rounded(to: 0)
        let minimumFractionNumber = Double("0." + String(1).leftPadding(to: minimumFractionDigits, pad: "0"))!
        let maximumFractionNumber = Double("0." + String(1).leftPadding(to: maximumFractionDigits, pad: "0"))!

        if int >= 1 || double == 0 {
            fractionDigits = minimumFractionDigits
        } else if double <= maximumFractionNumber {
            fractionDigits = maximumFractionDigits
        } else if double <= minimumFractionNumber {
            fractionDigits = maximumFractionDigits
        } else {
            fractionDigits = minimumFractionDigits
        }

        self.maximumFractionDigits = fractionDigits
        self.minimumFractionDigits = fractionDigits

        return (self.string(from: double as NSNumber) ?? "").trimmed
    }

}

fileprivate extension String {
    func leftPadding(to: Int, pad: String = " ") -> String {

        guard to > self.count else { return self }

        let padding = String(repeating: pad, count: to - self.count)
        return padding + self
    }
}
