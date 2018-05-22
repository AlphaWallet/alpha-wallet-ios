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
        return self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
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
        if self.count > 2 && self.substring(with: 0..<2) == "0x" {
            return String(self.dropFirst(2))
        }
        return self
    }

    var add0x: String {
        return "0x" + self
    }

    func toInt() -> Int? {
        return Int(self) ?? nil
    }

    func toBool() -> Bool {
        return (self.toInt()?.toBool())!
    }

    func toQRCode() -> UIImage? {
        let data = self.data(using: String.Encoding.ascii)
        return data?.toQRCode()
    }

    func isNumeric() -> Bool {
        let numberCharacters = CharacterSet.decimalDigits.inverted
        return !self.isEmpty && self.rangeOfCharacter(from: numberCharacters) == nil
    }

    func isNotNumeric() -> Bool {
        return !isNumeric()
    }

}

extension String {
    func index(from: Int) -> Index {
        return self.index(startIndex, offsetBy: from)
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
