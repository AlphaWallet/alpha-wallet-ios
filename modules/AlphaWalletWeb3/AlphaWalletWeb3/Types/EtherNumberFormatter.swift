// Copyright © 2023 Stormbird PTE. LTD.

import BigInt

//TODO why extension when the type is just below this extension
extension EtherNumberFormatter {
    public static func createFullEtherNumberFormatter() -> EtherNumberFormatter {
        return EtherNumberFormatter(locale: Web3Config.locale)
    }

    public static func createShortEtherNumberFormatter(maximumFractionDigits: Int) -> EtherNumberFormatter {
        let formatter = EtherNumberFormatter(locale: Web3Config.locale)
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter
    }

    public static func createShortPlainEtherNumberFormatter(maximumFractionDigits: Int) -> EtherNumberFormatter {
        //TODO maybe just pass in the locale. Then don't need Web3Config?
        let formatter = EtherNumberFormatter(locale: Web3Config.locale)
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.groupingSeparator = ""
        return formatter
    }

    public static func createPlainEtherNumberFormatter() -> EtherNumberFormatter {
        let formatter = EtherNumberFormatter(locale: Web3Config.locale)
        formatter.groupingSeparator = ""

        return formatter
    }
}

public final class EtherNumberFormatter {
    /// We always allow users to use "." as the decimal separator even if the locale might specify a different separator, eg. a decimal comma like Spain. If user sets their locale to one that uses a decimal comma, eg. Spain, the `.decimalPad` will still show "." instead of "," so the user wouldn't be able enter the "," that the locale expects using the keypad.
    public static let decimalPoint = "."

    /// Formatter that preserves full precision.
    public static var full: EtherNumberFormatter = .createFullEtherNumberFormatter()

    public static var short: EtherNumberFormatter = .createShortEtherNumberFormatter(maximumFractionDigits: Int.max)

    public static var shortPlain: EtherNumberFormatter = .createShortPlainEtherNumberFormatter(maximumFractionDigits: Int.max)

    public static var plain: EtherNumberFormatter = .createPlainEtherNumberFormatter()

    /// Minimum number of digits after the decimal point.
    public var minimumFractionDigits = 0

    /// Maximum number of digits after the decimal point.
    public var maximumFractionDigits = Int.max

    /// Decimal point.
    public var decimalSeparator = "."

    /// Thousands separator.
    public var groupingSeparator = ","

    public let locale: Locale

    /// Initializes a `EtherNumberFormatter` with a `Locale`.
    public init(locale: Locale = Web3Config.locale) {
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
    public func number(from string: String, units: EthereumUnit = .ether) -> BigInt? {
        let decimals = Int(log10(Double(units.rawValue)))
        return number(from: string, decimals: decimals)
    }

    /// Converts a string to a `BigInt`.
    ///
    /// - Parameters:
    ///   - string: string to convert
    ///   - decimals: decimal places used for scaling values.
    /// - Returns: `BigInt` representation.
    public func number(from string: String, decimals: Int) -> BigInt? {
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
    public func string(from number: BigInt, units: EthereumUnit = .ether) -> String {
        let decimals = Int(log10(Double(units.rawValue)))
        return string(from: number, decimals: decimals)
    }

    public func string(from number: BigUInt, units: EthereumUnit = .ether) -> String {
        let decimals = Int(log10(Double(units.rawValue)))
        precondition(minimumFractionDigits >= 0)
        precondition(maximumFractionDigits >= 0)

        return formatToPrecision(number.magnitude, decimals: decimals)
    }

    /// Formats a `BigInt` for displaying to the user.
    ///
    /// - Parameters:
    ///   - number: number to format
    ///   - decimals: decimal places used for scaling values.
    /// - Returns: string representation
    public func string(from number: BigInt, decimals: Int) -> String {
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

    public func string(from number: BigUInt, decimals: Int) -> String {
        return string(from: BigInt(number), decimals: decimals)
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
