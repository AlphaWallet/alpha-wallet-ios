// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public final class StringFormatter {
    public init() {}
    public func currency(with value: Double, and currencyCode: String = "") -> String {
        let formatter = NumberFormatter.currencyAccounting
        formatter.currencyCode = currencyCode
        //Trimming is important because the formatter output for `1.2` becomes "1.2 " (with trailing space) when region = Poland
        return (formatter.string(from: NSNumber(value: value))?.trimmed ?? "\(value)").droppedTrailingZeros
    }

    public func currency(with value: Double, currency: Currency, locale: Locale = .en_US, usesGroupingSeparator: Bool = true, fractionDigits: Int = Constants.formatterFractionDigits) -> String {
        let formatter = NumberFormatter.currencyAccounting
        formatter.locale = locale
        formatter.currencyCode = currency.rawValue
        formatter.usesGroupingSeparator = usesGroupingSeparator

        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits

        //Trimming is important because the formatter output for `1.2` becomes "1.2 " (with trailing space) when region = Poland
        return (formatter.string(double: value)?.trimmed ?? "\(value)").droppedTrailingZeros
    }

    public func alternateAmount(value: Double, locale: Locale = .en_US, usesGroupingSeparator: Bool = false, fractionDigits: Int = Constants.etherFormatterFractionDigits) -> String {
        let formatter = NumberFormatter.alternateAmount
        formatter.locale = locale
        formatter.usesGroupingSeparator = usesGroupingSeparator

        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits

        //For some reasons formatter adds trailing whitespace
        if let value = formatter.string(double: value) {
            return value.trimmingCharacters(in: .whitespacesAndNewlines).droppedTrailingZeros
        } else {
            return String(value)
        }
    }

    public func largeNumberFormatter(for double: Double, currency: String, decimals: Int = 1) -> String {
        let suffix = ["", "K", "M", "B", "T", "P", "E"]

        func formatNumber(_ number: Double) -> (value: Double, suffix: String) {
            var index = 0
            var value = number
            while (value / 1000) >= 1 {
               value /= 1000
               index += 1
            }
            return (value, suffix[index])
        }

        let result = formatNumber(double)
        return String(format: "%.\(decimals)f%@ %@", result.value, result.suffix, currency)
    }
}

extension Locale {
    public static var en_US: Locale {
        Locale(identifier: "en_US")
    }
}
