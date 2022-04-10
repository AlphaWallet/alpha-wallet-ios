// Copyright SIX DAY LLC. All rights reserved.

import Foundation

extension Data {
    internal struct HexEncodingOptions: OptionSet {
        public let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    internal func hex(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }

    internal var hexEncoded: String {
        return "0x" + self.hex()
    }

    init?(hexString: String) {
        let string: String
        if hexString.hasPrefix("0x") {
            string = String(hexString.dropFirst(2))
        } else {
            string = hexString
        }

        // Check odd length hex string
        if string.count % 2 != 0 {
            return nil
        }

        // Check odd characters
        if string.contains(where: { !$0.isHexDigit }) {
            return nil
        }

        // Convert the string to bytes for better performance
        guard let stringData = string.data(using: .ascii, allowLossyConversion: true) else {
            return nil
        }

        self.init(capacity: string.count / 2)
        let stringBytes = Array(stringData)
        for i in stride(from: 0, to: stringBytes.count, by: 2) {
            guard let high = functional.value(of: stringBytes[i]) else {
                return nil
            }
            if i < stringBytes.count - 1, let low = functional.value(of: stringBytes[i + 1]) {
                append((high << 4) | low)
            } else {
                append(high)
            }
        }
    }
}

extension Data {
    class functional {}
}

fileprivate extension Data.functional {
    /// Converts an ASCII byte to a hex value.
    static func value(of nibble: UInt8) -> UInt8? {
        guard let letter = String(bytes: [nibble], encoding: .ascii) else { return nil }
        return UInt8(letter, radix: 16)
    }
}