//
//  Data+Extensions.swift
//  AlphaWalletENS
//
//  Created by Hwee-Boon Yar on Apr/9/22.
//

import Foundation
import AlphaWalletCore

extension Data {
    var hexString: String {
        map({ String(format: "%02x", $0) }).joined()
    }
}
