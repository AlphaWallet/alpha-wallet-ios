// Copyright SIX DAY LLC. All rights reserved.

import UIKit

final class StringFormatter {
    /// currencyFormatter of a `StringFormatter` to represent current locale.
    private lazy var currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.currencySymbol = ""
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .down
        formatter.numberStyle = .currencyAccounting
        formatter.isLenient = true
        return formatter
    }()

    private let alternateAmountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.currencySymbol = ""
        formatter.minimumFractionDigits = Constants.etherFormatterFractionDigits
        formatter.maximumFractionDigits = Constants.etherFormatterFractionDigits
        formatter.roundingMode = .down
        formatter.numberStyle = .currency

        return formatter
    }()
    
    /// Converts a Double to a `currency String`.
    ///
    /// - Parameters:
    ///   - double: double to convert.
    ///   - currencyCode: code of the currency.
    /// - Returns: Currency `String` representation.
    func currency(with value: Double, and currencyCode: String = "") -> String {
        let formatter = currencyFormatter
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
    func currency(with value: NSDecimalNumber, and currencyCode: String = "", usesGroupingSeparator: Bool = true) -> String {
        let formatter = currencyFormatter
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
    func formatter(for double: Double, with precision: Int) -> String {
        return String(format: "%.\(precision)f", double)
    }
    /// Converts a Double to a `String`.
    ///
    /// - Parameters:
    ///   - double: double to convert.
    /// - Returns: `String` representation.
    func formatter(for double: Double) -> String {
        return String(format: "%f", double)
    }

    func alternateAmount(value: NSDecimalNumber, usesGroupingSeparator: Bool = false) -> String {
        alternateAmountFormatter.usesGroupingSeparator = usesGroupingSeparator

        //For some reasons formatter adds trailing whitespace
        if let value = alternateAmountFormatter.string(from: value) {
            return value.trimmingCharacters(in: .whitespacesAndNewlines).droppedTrailingZeros
        } else {
            return value.stringValue.droppedTrailingZeros
        } 
    }

    func largeNumberFormatter(for double: Double, currency: String) -> String {
        let suffix = ["", "K", "M", "B", "T", "P", "E"]

        func formatNumber(_ number: Double) -> (value: Double, suffix: String) {
            var index = 0
            var value = number
            while ((value / 1000) >= 1) {
               value /= 1000
               index += 1
            }
            return (value, suffix[index])
        }
        
        let result = formatNumber(double)
        return String(format: "%.1f%@ %@", result.value, result.suffix, currency)
    }
}
