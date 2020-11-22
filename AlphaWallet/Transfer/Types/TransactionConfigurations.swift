// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

struct TransactionConfigurations {
    private var others: [TransactionConfigurationType: TransactionConfiguration]

    var standard: TransactionConfiguration
    var custom: TransactionConfiguration

    var types: [TransactionConfigurationType] {
        others.keys + [.standard, .custom]
    }

    subscript(configurationType: TransactionConfigurationType) -> TransactionConfiguration? {
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

    init(standard: TransactionConfiguration) {
        self.others = .init()
        self.standard = standard
        self.custom = standard
    }
}