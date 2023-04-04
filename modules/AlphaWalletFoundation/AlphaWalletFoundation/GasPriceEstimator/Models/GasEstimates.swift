// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt

public struct GasEstimates {
    private var others: [GasSpeed: BigUInt]

    public var standard: BigUInt

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
}
