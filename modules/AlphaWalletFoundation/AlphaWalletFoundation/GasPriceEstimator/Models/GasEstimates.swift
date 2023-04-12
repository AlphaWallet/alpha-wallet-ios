// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt

public struct GasEstimates {
    private var others: [GasSpeed: BigUInt]

    public var standard: BigUInt
    public var keys: [GasSpeed] {
        others.keys.map { $0 }
    }
    
    public subscript(gasSpeed: GasSpeed) -> BigUInt? {
        get {
            switch gasSpeed {
            case .standard:
                return standard
            case .fast, .rapid, .slow:
                return others[gasSpeed]
            case .custom:
                return nil
            }
        }
        set(config) {
            switch gasSpeed {
            case .standard:
                //Better crash here than elsewhere or worse: hiding it
                standard = config!
            case .fast, .rapid, .slow:
                others[gasSpeed] = config
            case .custom:
                //Should not reach here
                break
            }
        }
    }

    public init(standard: BigUInt, others: [GasSpeed: BigUInt] = .init()) {
        self.others = others
        self.standard = standard
    }

    public var fastest: BigUInt? {
        for each in GasSpeed.sortedThirdPartyFastestFirst {
            if let config = others[each] {
                return config
            }
        }
        return nil
    }

    public var slowest: BigUInt? {
        for each in GasSpeed.sortedThirdPartyFastestFirst.reversed() {
            if let config = others[each] {
                return config
            }
        }
        return nil
    }
}
