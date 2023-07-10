// Copyright © 2023 Stormbird PTE. LTD.

extension Data {
    public init(json: Any, options: JSONSerialization.WritingOptions = []) throws {
        guard JSONSerialization.isValidJSONObject(json) else {
            throw DecodeError.initFailure
        }
        self = try JSONSerialization.data(withJSONObject: json, options: options)
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

    public struct HexEncodingOptions: OptionSet {
        public static let upperCase = HexEncodingOptions(rawValue: 1 << 0)

        public let rawValue: Int

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
}
