// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

enum ActivityOrTransaction {
    case activity(Activity)
    case transaction(Transaction)

    var date: Date {
        switch self {
        case .activity(let activity):
            return activity.date
        case .transaction(let transaction):
            return transaction.date
        }
    }
}
