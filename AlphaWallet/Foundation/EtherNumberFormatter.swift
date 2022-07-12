// Copyright SIX DAY LLC. All rights reserved.
import BigInt
import Foundation 

extension EtherNumberFormatter {

    static func createFullEtherNumberFormatter() -> EtherNumberFormatter {
        return EtherNumberFormatter(locale: Config.locale)
    }

    static func createShortEtherNumberFormatter() -> EtherNumberFormatter {
        let formatter = EtherNumberFormatter(locale: Config.locale)
        formatter.maximumFractionDigits = Constants.etherFormatterFractionDigits

        return formatter
    }

    static func createShortPlainEtherNumberFormatter() -> EtherNumberFormatter {
        let formatter = EtherNumberFormatter(locale: Config.locale)
        formatter.maximumFractionDigits = Constants.etherFormatterFractionDigits
        formatter.groupingSeparator = ""

        return formatter
    }

    static func createPlainEtherNumberFormatter() -> EtherNumberFormatter {
        let formatter = EtherNumberFormatter(locale: Config.locale)
        formatter.groupingSeparator = ""

        return formatter
    }
}

final class EtherNumberFormatter {
    /// We always allow users to use "." as the decimal separator even if the locale might specify a different separator, eg. a decimal comma like Spain. If user sets their locale to one that uses a decimal comma, eg. Spain, the `.decimalPad` will still show "." instead of "," so the user wouldn't be able enter the "," that the locale expects using the keypad.
    static let decimalPoint = "."

    /// Formatter that preserves full precision.
    static var full: EtherNumberFormatter = .createFullEtherNumberFormatter()

    static var short: EtherNumberFormatter = .createShortEtherNumberFormatter()

    static var shortPlain: EtherNumberFormatter = .createShortPlainEtherNumberFormatter()

    static var plain: EtherNumberFormatter = .createPlainEtherNumberFormatter()

    /// Minimum number of digits after the decimal point.
    var minimumFractionDigits = 0

    /// Maximum number of digits after the decimal point.
    var maximumFractionDigits = Int.max

    /// Decimal point.
    var decimalSeparator = "."

    /// Thousands separator.
    var groupingSeparator = ","

    let locale: Locale

    /// Initializes a `EtherNumberFormatter` with a `Locale`.
    init(locale: Locale = Config.locale) {
        self.locale = locale

        decimalSeparator = locale.decimalSeparator ?? "."
        groupingSeparator = locale.groupingSeparator ?? ","
    }

    /// Converts a string to a `BigInt`.
    ///
    /// - Parameters:
    ///   - string: string to convert
    ///   - units: units to use
    /// - Returns: `BigInt` representation.
    func number(from string: String, units: EthereumUnit = .ether) -> BigInt? {
        let decimals = Int(log10(Double(units.rawValue)))
        return number(from: string, decimals: decimals)
    }

    /// Converts a string to a `BigInt`.
    ///
    /// - Parameters:
    ///   - string: string to convert
    ///   - decimals: decimal places used for scaling values.
    /// - Returns: `BigInt` representation.
    func number(from string: String, decimals: Int) -> BigInt? {
        guard let index = string.index(where: { String($0) == decimalSeparator }) ?? string.index(where: { String($0) == EtherNumberFormatter.decimalPoint }) else {
            // No fractional part
            return BigInt(string).flatMap({ $0 * BigInt(10).power(decimals) })
        }

        let fractionalDigits = string.distance(from: string.index(after: index), to: string.endIndex)
        if fractionalDigits > decimals {
            // Can't represent number accurately
            return nil
        }

        var fullString = string
        fullString.remove(at: index)

        guard let number = BigInt(fullString) else {
            return nil
        }

        if fractionalDigits < decimals {
            return number * BigInt(10).power(decimals - fractionalDigits)
        } else {
            return number
        }
    }

    /// Formats a `BigInt` for displaying to the user.
    ///
    /// - Parameters:
    ///   - number: number to format
    ///   - units: units to use
    /// - Returns: string representation
    func string(from number: BigInt, units: EthereumUnit = .ether) -> String {
        let decimals = Int(log10(Double(units.rawValue)))
        return string(from: number, decimals: decimals)
    }

    /// Formats a `BigInt` for displaying to the user.
    ///
    /// - Parameters:
    ///   - number: number to format
    ///   - decimals: decimal places used for scaling values.
    /// - Returns: string representation
    func string(from number: BigInt, decimals: Int) -> String {
        precondition(minimumFractionDigits >= 0)
        precondition(maximumFractionDigits >= 0)

        let formatted = formatToPrecision(number.magnitude, decimals: decimals)
        switch number.sign {
        case .plus:
            return formatted
        case .minus:
            return "-" + formatted
        }
    }

    private func integerString(from: BigInt) -> String {
        var string = from.description
        let end = from.sign == .minus ? 1 : 0
        for offset in stride(from: string.count - 3, to: end, by: -3) {
            let index = string.index(string.startIndex, offsetBy: offset)
            string.insert(contentsOf: groupingSeparator, at: index)
        }
        return string
    }

    private func formatToPrecision(_ number: BigUInt, decimals: Int) -> String {
        guard number != 0 else { return "0" }

        let divisor = BigUInt(10).power(decimals)
        let (quotient, remainder) = number.quotientAndRemainder(dividingBy: divisor)

        let remainderFormatted = fractionalString(from: remainder, quotient: quotient, decimals: decimals)
        if remainderFormatted.isEmpty {
            return integerString(from: BigInt(quotient))
        } else {
            return integerString(from: BigInt(quotient)) + decimalSeparator + remainderFormatted
        } 
    }

    private func fractionalString(from remainder: BigUInt, quotient: BigUInt, decimals: Int) -> String {
        var formattingDecimals = maximumFractionDigits
        if decimals < maximumFractionDigits {
            formattingDecimals = decimals
        }
        guard formattingDecimals != 0 else { return "" }

        let fullPaddedRemainder = String(remainder).leftPadding(toLength: decimals, withPad: "0")
        var remainderPadded = fullPaddedRemainder[0 ..< formattingDecimals]

        // Remove extra zeros after the decimal point.
        if let lastNonZeroIndex = remainderPadded.reversed().index(where: { $0 != "0" })?.base {
            let numberOfZeros = remainderPadded.distance(from: remainderPadded.startIndex, to: lastNonZeroIndex)
            if numberOfZeros > minimumFractionDigits {
                let newEndIndex = remainderPadded.index(remainderPadded.startIndex, offsetBy: numberOfZeros - minimumFractionDigits)
                remainderPadded = String(remainderPadded[remainderPadded.startIndex..<newEndIndex])
            }
        }

        if remainderPadded == String(repeating: "0", count: formattingDecimals) {
            if quotient != 0 {
                return ""
            }
        }

        return remainderPadded
    }
}

fileprivate extension String {

    subscript (bounds: CountableClosedRange<Int>) -> String {
        let start = index(self.startIndex, offsetBy: bounds.lowerBound)
        let end = index(self.startIndex, offsetBy: bounds.upperBound)
        return String(self[start...end])
    }

    subscript (bounds: CountableRange<Int>) -> String {
        let start = index(self.startIndex, offsetBy: bounds.lowerBound)
        let end = index(self.startIndex, offsetBy: bounds.upperBound)
        return String(self[start..<end])
    }

    subscript (bounds: CountablePartialRangeFrom<Int>) -> String {
        let start = index(self.startIndex, offsetBy: bounds.lowerBound)
        let end = self.endIndex
        return String(self[start..<end])
    }

    func leftPadding(toLength: Int, withPad character: Character) -> String {
        let stringLength = self.count
        if stringLength < toLength {
            return String(repeatElement(character, count: toLength - stringLength)) + self
        } else {
            return String(self.suffix(toLength))
        }
    }
}
