// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

public struct GasPriceConfiguration {
    static let `default`: BigInt = EtherNumberFormatter.full.number(from: "9", units: UnitConfiguration.gasPriceUnit)!
    static let min: BigInt = EtherNumberFormatter.full.number(from: "1", units: UnitConfiguration.gasPriceUnit)!
    static let limit: BigInt = EtherNumberFormatter.full.number(from: "470", units: UnitConfiguration.gasPriceUnit)! //roughly the geth default
}
