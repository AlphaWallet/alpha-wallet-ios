// Copyright SIX DAY LLC. All rights reserved.

import Foundation

final class DecimalFormatter {
    var groupingSeparator: String {
        return numberFormatter.groupingSeparator
    }
    /// Locale of a `DecimalFormatter`.
    var locale: Locale
    /// numberFormatter of a `DecimalFormatter` to represent current locale.
    private lazy var numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.isLenient = true
        return formatter
    }()
    /// usFormatter of a `DecimalFormatter` to represent decimal separator ".".
    private lazy var usFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.isLenient = true
        return formatter
    }()
    /// frFormatter of a `DecimalFormatter` to represent decimal separator ",".
    private lazy var frFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.isLenient = true
        return formatter
    }()
    /// enCaFormatter of a `DecimalFormatter` to represent decimal separator "'".
    private lazy var enCaFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_CA")
        formatter.numberStyle = .decimal
        formatter.isLenient = true
        return formatter
    }()
    /// Initializes a `DecimalFormatter` with a `Locale`.
    init(locale: Locale = Config.locale) {
        self.locale = locale
        self.numberFormatter = NumberFormatter()
        self.numberFormatter.locale = self.locale
        self.numberFormatter.numberStyle = .decimal
        self.numberFormatter.isLenient = true
    }
    /// Converts a String to a `NSNumber`.
    ///
    /// - Parameters:
    ///   - string: string to convert.
    /// - Returns: `NSNumber` representation.
    func number(from string: String) -> NSNumber? {
        return numberFormatter.number(from: string) ?? usFormatter.number(from: string) ?? frFormatter.number(from: string) ?? enCaFormatter.number(from: string)
    }
    /// Converts a NSNumber to a `String`.
    ///
    /// - Parameters:
    ///   - number: NSNumber to convert.
    /// - Returns: `NSumber` representation.
    func string(from number: NSNumber) -> String? {
        return numberFormatter.string(from: number)
    }
}
