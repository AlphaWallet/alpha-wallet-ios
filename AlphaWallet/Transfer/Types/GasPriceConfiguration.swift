// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

public struct GasPriceConfiguration {
    static let `default` = BigInt(90_000)
    static let min = BigInt(21_000)
    static let limit = BigInt(4_712_388) //geth default limit
}
