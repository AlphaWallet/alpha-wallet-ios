//
//  Data+Extensions.swift
//  AlphaWalletENS
//
//  Created by Hwee-Boon Yar on Apr/9/22.
//

import Foundation

extension Data {
    struct HexEncodingOptions: OptionSet {
        public let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    var hexString: String {
        map({ String(format: "%02x", $0) }).joined()
    }

    func hex(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
}
