// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt

extension String {

    //NOTE: as minimum chunck is as min time it will be executed, during testing we found that optimal chunck size is 100, but seems it could be optimized more, execution time (0.2 seconds), pretty good and doesn't block UI
    public var toHexData: Data {
        if self.hasPrefix("0x") {
            return Data(_hex: self, chunkSize: 100)
        } else {
            return Data(_hex: self.hex, chunkSize: 100)
        }
    }
}

extension String {
    public var hex: String {
        guard let data = self.data(using: .utf8) else {
            return String()
        }

        return data.map {
            String(format: "%02x", $0)
        }.joined()
    }

    public var hexEncoded: String {
        guard let data = self.data(using: .utf8) else {
            return String()
        }
        return data.hexEncoded
    }

    public var isHexEncoded: Bool {
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

    public var trimmed: String {
        return trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    public var asDictionary: [String: Any]? {
        if let data = self.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                return [:]
            }
        }
        return [:]
    }

    public var has0xPrefix: Bool {
        return hasPrefix("0x")
    }

    public var isPrivateKey: Bool {
        let value = self.drop0x.components(separatedBy: " ").joined()
        return value.count == 64
    }

    public var drop0x: String {
        if count > 2 && substring(with: 0..<2) == "0x" {
            return String(dropFirst(2))
        }
        return self
    }

    public var add0x: String {
        if hasPrefix("0x") {
            return self
        } else {
            return "0x" + self
        }
    }

    public var dropParenthesis: String {
        if hasSuffix("()") {
            return String(dropLast(2))
        } else {
            return self
        }
    }

    public func toInt() -> Int? {
        return Int(self) ?? nil
    }

    public func toBool() -> Bool {
        return (toInt()?.toBool())!
    }

    public func toQRCode() -> UIImage? {
        let data = self.data(using: String.Encoding.ascii)
        return data?.toQRCode()
    }

    public func isNumeric() -> Bool {
        let numberCharacters = CharacterSet.decimalDigits.inverted
        return !isEmpty && rangeOfCharacter(from: numberCharacters) == nil
    }

    public func isNotNumeric() -> Bool {
        return !isNumeric()
    }
}

extension String {
    public func index(from: Int) -> Index {
        return index(startIndex, offsetBy: from)
    }

    public func substring(from: Int) -> String {
        let fromIndex = index(from: from)
        return String(self[fromIndex...])
    }

    public func substring(to: Int) -> String {
        let toIndex = index(from: to)
        return String(self[..<toIndex])
    }

    public func substring(with r: Range<Int>) -> String {
        let startIndex = index(from: r.lowerBound)
        let endIndex = index(from: r.upperBound)
        return String(self[startIndex..<endIndex])
    }

    public func nextLetterInAlphabet(for index: Int) -> String? {
        guard let uniCode = UnicodeScalar(self) else {
            return nil
        }
        switch uniCode {
        case "A"..<"Z":
            return String(UnicodeScalar(uniCode.value.advanced(by: index))!)
        default:
            return nil
        }
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

extension StringProtocol {

    public func chunked(into size: Int) -> [SubSequence] {
        var chunks: [SubSequence] = []

        var i = startIndex

        while let nextIndex = index(i, offsetBy: size, limitedBy: endIndex) {
            chunks.append(self[i ..< nextIndex])
            i = nextIndex
        }

        let finalChunk = self[i ..< endIndex]

        if finalChunk.isEmpty == false {
            chunks.append(finalChunk)
        }

        return chunks
    }
}

extension String {

    public var scientificAmountToBigInt: BigInt? {
        let numberFormatter = Formatter.scientificAmount

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

extension String {
    public var hashForCachingHeight: Int {
        return hashValue
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
