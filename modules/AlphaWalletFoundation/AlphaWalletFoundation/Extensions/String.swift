// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt

extension String {
    var isHexEncoded: Bool {
        guard starts(with: "0x") else {
            return false
        }
        let regex = try! NSRegularExpression(pattern: "^0x[0-9A-Fa-f]*$")
        if regex.matches(in: self, range: NSRange(startIndex..., in: self)).isEmpty {
            return false
        }
        return true
    }

    public var doubleValue: Double {
        return optionalDecimalValue?.doubleValue ?? 0.0
    }

    public var dropParenthesis: String {
        if hasSuffix("()") {
            return String(dropLast(2))
        } else {
            return self
        }
    }

    public func toInt() -> Int? {
        return Int(self)
    }

    public func toQRCode() -> UIImage? {
        return data(using: String.Encoding.ascii)?.toQRCode()
    }

    public func isNumeric() -> Bool {
        let numberCharacters = CharacterSet.decimalDigits.inverted
        return !isEmpty && rangeOfCharacter(from: numberCharacters) == nil
    }
}

extension String {
    public func capitalizingFirstLetter() -> String {
        return prefix(1).uppercased() + dropFirst()
    }

    public func titleCasedWords() -> String {
        return split(separator: " ").map { String($0).capitalizingFirstLetter() }.joined(separator: " ")
    }

    public func insertSpaceBeforeCapitals() -> String {
        var buffer = [String]()
        var word: String = ""
        for character in self {
            guard let lastLetter = word.last else {
                word.append(character)
                continue
            }
            if !character.isUppercase, lastLetter.isUppercase {
                if !word.isEmpty, word.count > 1 {
                    word.removeLast()
                    buffer.append(word)
                    word = ""
                    word.append(lastLetter)
                }
                word.append(character)
                continue
            }
            if character.isUppercase, !lastLetter.isUppercase {
                if !word.isEmpty {
                    buffer.append(word)
                    word = ""
                }
                word.append(character)
                continue
            }
            word.append(character)
        }
        if !word.isEmpty {
            buffer.append(word)
        }
        return buffer.joined(separator: " ")
    }

}

extension String {

    public var scientificAmountToBigInt: BigInt? {
        let numberFormatter = NumberFormatter.scientificAmount

        let amountString = numberFormatter.number(from: self).flatMap { numberFormatter.string(from: $0) }
        return amountString.flatMap { BigInt($0) }
    }

    public var isValidJSON: Bool {
        guard let jsonData = self.data(using: .utf8) else { return false }

        return (try? JSONSerialization.jsonObject(with: jsonData)) != nil
    }
    static let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    public var isValidURL: Bool {
        if let match = String.detector.firstMatch(in: self, options: [], range: NSRange(location: 0, length: utf16.count)) {
            // it is a link, if the match covers the whole string
            return match.range.length == utf16.count
        } else {
            return false
        }
    }
}

extension String {
    public var removingPrefixWhitespacesAndNewlines: String {
        guard let index = firstIndex(where: { !CharacterSet(charactersIn: String($0)).isSubset(of: .whitespacesAndNewlines) }) else {
            return self
        }
        return String(self[index...])
    }

    public var removingWhitespacesAndNewlines: String {
        let value = components(separatedBy: .whitespacesAndNewlines)
        return value.joined()
    }
}

extension String {
    public var isValidAsEmail: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"

        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return predicate.evaluate(with: self)
    }
}

extension Character {
    public var toString: String {
        return String(self)
    }
}

extension String {

    ///Allow to convert locale based decimal number to its Double value supports strings like `123,123.12`
    public var optionalDecimalValue: NSDecimalNumber? {
        if let value = EtherNumberFormatter.plain.decimal(from: self) {
            return value
        //NOTE: for case when formatter configured with `,` decimal separator, but EtherNumberFormatter.plain.decimal returns value with `.` separator
        } else if let asDoubleValue = Double(self) {
            return NSDecimalNumber(value: asDoubleValue)
        } else {
            return .none
        }
    }

    public var droppedTrailingZeros: String {
        var string = self
        let decimalSeparator = Config.locale.decimalSeparator ?? "."

        //NOTE: it seems like we need to remove trailing zeros only in case when string contains `decimalSeparator`
        guard string.contains(decimalSeparator) else { return string }

        while string.last == "0" || string.last?.toString == decimalSeparator {
            if string.last?.toString == decimalSeparator {
                string = String(string.dropLast())
                break
            }
            string = String(string.dropLast())
        }

        return string
    }

}

extension Optional where Self.Wrapped == NSDecimalNumber {
    public var localizedString: String {
        switch self {
        case .none:
            return String()
        case .some(let value):
            return value.localizedString
        }
    }
}

extension NSDecimalNumber {
    public var localizedString: String {
        return self.description(withLocale: Config.locale)
    }
}

extension EtherNumberFormatter {

    /// returns NSDecimalNumber? value from `value` formatted with `EtherNumberFormatter`s selected locale
    public func decimal(from value: String) -> NSDecimalNumber? {
        let value = NSDecimalNumber(string: value, locale: locale)
        if value == .notANumber {
            return .none
        } else {
            return value
        }
    }
}
