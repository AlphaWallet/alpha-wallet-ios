// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt

public struct GasEstimates {
    private var others: [TransactionConfigurationType: BigUInt]

    public var standard: BigUInt

    public subscript(configurationType: TransactionConfigurationType) -> BigUInt? {
        get {
            switch configurationType {
            case .standard:
                return standard
            case .fast, .rapid, .slow:
                return others[configurationType]
            case .custom:
                return nil
            }
        }
        set(config) {
            switch configurationType {
            case .standard:
                //Better crash here than elsewhere or worse: hiding it
                standard = config!
            case .fast, .rapid, .slow:
                others[configurationType] = config
            case .custom:
                //Should not reach here
                break
            }
        }
    }

    public init(standard: BigUInt, others: [TransactionConfigurationType: BigUInt] = .init()) {
        self.others = others
        self.standard = standard
    }
}
