// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

protocol AnalyticsNavigation {
    var rawValue: String { get }
}

protocol AnalyticsAction {
    var rawValue: String { get }
}

enum Analytics {
    enum Navigation: String, AnalyticsNavigation {
        case placeholder
    }

    enum Action: String, AnalyticsAction {
        case placeholder
    }

    enum Properties {
        static let address = "Address"
        static let addressFrom = "From"
        static let addressTo = "To"
        static let amount = "Amount"
    }
}
