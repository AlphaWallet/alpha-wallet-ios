// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public final class StringFormatter {
    public init() {}
    /// Converts a Double to a `currency String`.
    ///
    /// - Parameters:
    ///   - double: double to convert.
    ///   - currencyCode: code of the currency.
    /// - Returns: Currency `String` representation.
    public func currency(with value: Double, and currencyCode: String = "") -> String {
        let formatter = Formatter.currencyAccounting
        formatter.currencyCode = currencyCode
        //Trimming is important because the formatter output for `1.2` becomes "1.2 " (with trailing space) when region = Poland
        return (formatter.string(from: NSNumber(value: value))?.trimmed ?? "\(value)").droppedTrailingZeros
    }
    /// Converts a NSDecimalNumber to a `currency String`.
    ///
    /// - Parameters:
    ///   - double: double to convert.
    ///   - currencyCode: code of the currency.
    /// - Returns: Currency `String` representation.
    public func currency(with value: NSDecimalNumber, and currencyCode: String = "", usesGroupingSeparator: Bool = true) -> String {
        let formatter = Formatter.currencyAccounting
        formatter.currencyCode = currencyCode
        formatter.usesGroupingSeparator = usesGroupingSeparator

        //Trimming is important because the formatter output for `1.2` becomes "1.2 " (with trailing space) when region = Poland
        return (formatter.string(from: value)?.trimmed ?? "\(value)").droppedTrailingZeros
    }
    /// Converts a Double to a `String`.
    ///
    /// - Parameters:
    ///   - double: double to convert.
    ///   - precision: symbols after coma.
    /// - Returns: `String` representation.
    public func formatter(for double: Double, with precision: Int) -> String {
        return String(format: "%.\(precision)f", double)
    }
    /// Converts a Double to a `String`.
    ///
    /// - Parameters:
    ///   - double: double to convert.
    /// - Returns: `String` representation.
    public func formatter(for double: Double) -> String {
        return String(format: "%f", double)
    }

    public func alternateAmount(value: NSDecimalNumber, usesGroupingSeparator: Bool = false) -> String {
        let formatter = Formatter.alternateAmount
        formatter.usesGroupingSeparator = usesGroupingSeparator

        //For some reasons formatter adds trailing whitespace
        if let value = formatter.string(from: value) {
            return value.trimmingCharacters(in: .whitespacesAndNewlines).droppedTrailingZeros
        } else {
            return value.stringValue.droppedTrailingZeros
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
