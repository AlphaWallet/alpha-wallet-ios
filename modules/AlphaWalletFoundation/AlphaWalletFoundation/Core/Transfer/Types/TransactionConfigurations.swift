// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

public struct TransactionConfigurations {
    private var others: [TransactionConfigurationType: TransactionConfiguration]

    public var standard: TransactionConfiguration
    public var custom: TransactionConfiguration

    public var types: [TransactionConfigurationType] {
        others.keys + [.standard, .custom]
    }

    public var fastestThirdPartyConfiguration: TransactionConfiguration? {
        for each in TransactionConfigurationType.sortedThirdPartyFastestFirst {
            if let config = others[each] {
                return config
            }
        }
        return nil
    }

    public var slowestThirdPartyConfiguration: TransactionConfiguration? {
        for each in TransactionConfigurationType.sortedThirdPartyFastestFirst.reversed() {
            if let config = others[each] {
                return config
            }
        }
        return nil
    }

    public subscript(configurationType: TransactionConfigurationType) -> TransactionConfiguration? {
        get {
            switch configurationType {
            case .standard:
                return standard
            case .custom:
                return custom
            case .fast, .rapid, .slow:
                return others[configurationType]
            }
        }
        set(config) {
            switch configurationType {
            case .standard:
                //Better crash here than elsewhere or worse: hiding it
                standard = config!
            case .custom:
                //Better crash here than elsewhere or worse: hiding it
                custom = config!
            case .fast, .rapid, .slow:
                others[configurationType] = config
            }
        }
    }

    public init(standard: TransactionConfiguration) {
        self.others = .init()
        self.standard = standard
        self.custom = standard
    }
}
