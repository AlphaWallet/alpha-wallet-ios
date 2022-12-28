// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import CoreImage
import AlphaWalletWeb3

extension Data {

    public init(json: Any, options: JSONSerialization.WritingOptions = []) throws {
        guard JSONSerialization.isValidJSONObject(json) else {
            throw DecodeError.initFailure
        }
        self = try JSONSerialization.data(withJSONObject: json, options: options)
    }

    public struct HexEncodingOptions: OptionSet {
        public let rawValue: Int
        public static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    public func hex(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }

    public var hexEncoded: String {
        return "0x" + self.hex()
    }

    //NOTE: as minimum chunck is as min time it will be executed, during testing we found that optimal chunck size is 100, but seems it could be optimized more, execution time (0.2 seconds), pretty good and doesn't block UI
    public init(_hex value: String) {
        let chunkSize: Int = 100
        if value.count > chunkSize {
            self = value.chunked(into: chunkSize).reduce(NSMutableData()) { result, chunk -> NSMutableData in
                let part = Data.data(from: String(chunk))
                result.append(part)

                return result
            } as Data
        } else {
            self = Data.data(from: value)
        }
    }

    //NOTE: renamed to `_hex` because CryptoSwift has its own implementation of `.init(hex:)` that instantiates Data() object with additionaly byte at the end. That brokes `signing` in app. Not sure that this is good name.
    private static func data(from hex: String) -> Data {
        let len = hex.count / 2
        var data = Data(capacity: len)
        for i in 0..<len {
            let from = hex.index(hex.startIndex, offsetBy: i*2)
            let to = hex.index(hex.startIndex, offsetBy: i*2 + 2)
            let bytes = hex[from ..< to]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            }
        }
        return data
    }

    //TODO remove if unused. Also confusing
    public init?(fromHexEncodedString string: String) {
        // Convert 0 ... 9, a ... f, A ...F to their decimal value,
        // return nil for all other input characters
        func decodeNibble(u: UInt16) -> UInt8? {
            switch u {
            case 0x30 ... 0x39:
                return UInt8(u - 0x30)
            case 0x41 ... 0x46:
                return UInt8(u - 0x41 + 10)
            case 0x61 ... 0x66:
                return UInt8(u - 0x61 + 10)
            default:
                return nil
            }
        }

        self.init(capacity: string.utf16.count/2)
        var even = true
        var byte: UInt8 = 0
        for c in string.utf16 {
            guard let val = decodeNibble(u: c) else { return nil }
            if even {
                byte = val << 4
            } else {
                byte += val
                append(byte)
            }
            even = !even
        }
        guard even else { return nil }
    }

    public func toString() -> String? {
        return String(data: self, encoding: .utf8)
    }

    public func toQRCode() -> UIImage? {
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(self, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 7, y: 7)
            if let output = filter.outputImage?.transformed(by: transform) {
                return UIImage(ciImage: output)
            }
        }
        return nil
    }
}
