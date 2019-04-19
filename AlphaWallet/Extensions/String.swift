// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

extension String {
    var hex: String {
        let data = self.data(using: .utf8)!
        return data.map {
            String(format: "%02x", $0)
        }.joined()
    }

    var hexEncoded: String {
        let data = self.data(using: .utf8)!
        return data.hexEncoded
    }

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

    var doubleValue: Double {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.decimalSeparator = "."
        if let result = formatter.number(from: self) {
            return result.doubleValue
        } else {
            formatter.decimalSeparator = ","
            if let result = formatter.number(from: self) {
                return result.doubleValue
            }
        }
        return 0
    }

    var trimmed: String {
        return trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    var asDictionary: [String: Any]? {
        if let data = self.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
                return [:]
            }
        }
        return [:]
    }

    var drop0x: String {
        if count > 2 && substring(with: 0..<2) == "0x" {
            return String(dropFirst(2))
        }
        return self
    }

    var add0x: String {
        if hasPrefix("0x") {
            return self
        } else {
            return "0x" + self
        }
    }

    var dropParenthesis: String {
        if hasSuffix("()") {
            return String(dropLast(2))
        } else {
            return self
        }
    }

    func toInt() -> Int? {
        return Int(self) ?? nil
    }

    func toBool() -> Bool {
        return (toInt()?.toBool())!
    }

    func toQRCode() -> UIImage? {
        let data = self.data(using: String.Encoding.ascii)
        return data?.toQRCode()
    }

    func isNumeric() -> Bool {
        let numberCharacters = CharacterSet.decimalDigits.inverted
        return !isEmpty && rangeOfCharacter(from: numberCharacters) == nil
    }

    func isNotNumeric() -> Bool {
        return !isNumeric()
    }

    func sameContract(as contract: String) -> Bool {
        return drop0x.lowercased() == contract.drop0x.lowercased()
    }

    var isLegacy875Contract: Bool {
        return Constants.legacy875Addresses.contains { $0.sameContract(as: self) }
    }

    var isLegacy732Contract: Bool {
        return Constants.legacy721Addresses.contains { $0.sameContract(as: self) }
    }

}

extension String {
    func index(from: Int) -> Index {
        return index(startIndex, offsetBy: from)
    }

    func substring(from: Int) -> String {
        let fromIndex = index(from: from)
        return String(self[fromIndex...])
    }

    func substring(to: Int) -> String {
        let toIndex = index(from: to)
        return String(self[..<toIndex])
    }

    func substring(with r: Range<Int>) -> String {
        let startIndex = index(from: r.lowerBound)
        let endIndex = index(from: r.upperBound)
        return String(self[startIndex..<endIndex])
    }

    func nextLetterInAlphabet(for index: Int) -> String? {
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
    func capitalizingFirstLetter() -> String {
        return prefix(1).uppercased() + dropFirst()
    }

    func titleCasedWords() -> String {
        return split(separator: " ").map { String($0).capitalizingFirstLetter() }.joined(separator: " ")
    }
}
