// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import AlphaWalletCore

extension Int {
    public func toString() -> String {
        return String(self)
    }

    //We'll take both "0x12" and "18" as `18`. The former is as spec like https://eips.ethereum.org/EIPS/eip-695, the latter to be more forgiving of dapps
    public  init?(chainId0xString string: String) {
        if string.has0xPrefix {
            if let i = Int(string.drop0x, radix: 16) {
                self = i
            } else {
                return nil
            }
        } else {
            if let i = Int(string) {
                self = i
            } else {
                return nil
            }
        }
    }
}
