//Copyright © 2022 Stormbird PTE. LTD.

import Foundation 

enum TransactionsFilterStrategy {
    case all
    case predicate(NSPredicate)
    case filter(strategy: ActivitiesFilterStrategy, token: Token)
}
