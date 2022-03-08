// Copyright SIX DAY LLC. All rights reserved.

import UIKit

extension String {

    //NOTE: as minimum chunck is as min time it will be executed, during testing we found that optimal chunck size is 100, but seems it could be optimized more, execution time (0.2 seconds), pretty good and doesn't block UI
    var toHexData: Data {
        if self.hasPrefix("0x") {
            return Data(_hex: self, chunkSize: 100)
        } else {
            return Data(_hex: self.hex, chunkSize: 100)
        }
    }
}

extension String {
    var hex: String {
        guard let data = self.data(using: .utf8) else {
            return String()
        }

        return data.map {
            String(format: "%02x", $0)
        }.joined()
    }

    var hexEncoded: String {
        guard let data = self.data(using: .utf8) else {
            return String()
        }
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
        return optionalDecimalValue?.doubleValue ?? 0.0
    }

    var trimmed: String {
        return trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    var asDictionary: [String: Any]? {
        if let data = self.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                return [:]
            }
        }
        return [:]
    }

    var has0xPrefix: Bool {
        return hasPrefix("0x")
    }

    var isPrivateKey: Bool {
        let value = self.drop0x.components(separatedBy: " ").joined()
        return value.count == 64
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
