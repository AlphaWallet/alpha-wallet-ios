// Copyright © 2023 Stormbird PTE. LTD.

extension Optional where Wrapped == String {
    public var nilIfEmpty: String? {
        guard let strongSelf = self else { return nil }
        if strongSelf.isEmpty {
            return nil
        } else {
            return strongSelf
        }
    }
}
extension String {
    public var nilIfEmpty: String? {
        if isEmpty {
            return nil
        } else {
            return self
        }
    }
}

extension String {
    public var hexToBytes: [UInt8] {
        let hex: [Character]
        if count % 2 == 0 {
            hex = Array(self)
        } else {
            hex = Array(("0" + self))
        }
        return stride(from: 0, to: count, by: 2).compactMap {
            UInt8(String(hex[$0..<$0.advanced(by: 2)]), radix: 16)
        }
    }

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

    public var trimmed: String {
        return trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    public var hex: String {
        guard let data = self.data(using: .utf8) else {
            return String()
        }

        return data.map { String(format: "%02x", $0) }.joined() }

    internal var hexEncoded: String {
        let data = Data(self.utf8)
        return data.hexEncoded
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
}
