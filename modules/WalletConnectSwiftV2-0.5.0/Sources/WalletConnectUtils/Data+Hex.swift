//

import Foundation

extension Data {

    static func value(of nibble: UInt8) -> UInt8? {
        guard let letter = String(bytes: [nibble], encoding: .ascii) else { return nil }
        return UInt8(letter, radix: 16)
    }

    public init(hex: String) {
        var data = Data()
        let string = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex

        // Convert the string to bytes for better performance
        guard
            let stringData = string.data(using: .ascii, allowLossyConversion: true)
        else {
            self = data
            return
        }

        let stringBytes = Array(stringData)
        for idx in stride(from: 0, to: stringBytes.count, by: 2) {
            guard let high = Data.value(of: stringBytes[idx]) else {
                data.removeAll()
                break
            }
            if idx < stringBytes.count - 1, let low = Data.value(of: stringBytes[idx + 1]) {
                data.append((high << 4) | low)
            } else {
                data.append(high)
            }
        }
        self = data
    }

    public func toHexString() -> String {
        return map({ String(format: "%02x", $0) }).joined()
    }
}
