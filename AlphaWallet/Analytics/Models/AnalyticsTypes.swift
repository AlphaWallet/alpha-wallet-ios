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
        case actionSheetForTransactionConfirmation = "Screen: Txn Confirmation"
    }

    enum Action: String, AnalyticsAction {
        case confirmsTransactionInActionSheet = "Txn Confirmation Confirm Tapped"
        case cancelsTransactionInActionSheet = "Txn Confirmation Cancelled"
    }

    enum Properties {
        static let address = "Address"
        static let addressFrom = "From"
        static let addressTo = "To"
        static let amount = "Amount"
    }
}
