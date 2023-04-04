// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

public struct TransactionConfigurations {
    private var others: [GasSpeed: TransactionConfiguration]

    public var standard: TransactionConfiguration
    public var custom: TransactionConfiguration

    public var types: [GasSpeed] {
        others.keys + [.standard, .custom]
    }

    public var fastestThirdPartyConfiguration: TransactionConfiguration? {
        for each in GasSpeed.sortedThirdPartyFastestFirst {
            if let config = others[each] {
                return config
            }
        }
        return nil
    }

    public var slowestThirdPartyConfiguration: TransactionConfiguration? {
        for each in GasSpeed.sortedThirdPartyFastestFirst.reversed() {
            if let config = others[each] {
                return config
            }
        }
        return nil
    }

    public subscript(gasSpeed: GasSpeed) -> TransactionConfiguration? {
        get {
            switch gasSpeed {
            case .standard:
                return standard
            case .custom:
                return custom
            case .fast, .rapid, .slow:
                return others[gasSpeed]
            }
        }
        set(config) {
            switch gasSpeed {
            case .standard:
                //Better crash here than elsewhere or worse: hiding it
                standard = config!
            case .custom:
                //Better crash here than elsewhere or worse: hiding it
                custom = config!
            case .fast, .rapid, .slow:
                others[gasSpeed] = config
            }
        }
    }

    public init(standard: TransactionConfiguration) {
        self.others = .init()
        self.standard = standard
        self.custom = standard
    }
}
