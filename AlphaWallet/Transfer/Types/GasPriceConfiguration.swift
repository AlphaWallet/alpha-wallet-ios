// Copyright SIX DAY LLC. All rights reserved.
// This struct sets the price for each unit of gas

import Foundation
import BigInt

public struct GasPriceConfiguration {
    static let defaultPrice: BigInt = EtherNumberFormatter.full.number(from: "9", units: UnitConfiguration.gasPriceUnit)!
    static let minPrice: BigInt = EtherNumberFormatter.full.number(from: "1", units: UnitConfiguration.gasPriceUnit)!
    static let maxPrice: BigInt = EtherNumberFormatter.full.number(from: "100", units: UnitConfiguration.gasPriceUnit)!
}