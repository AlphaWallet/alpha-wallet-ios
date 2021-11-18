// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

struct ChooseSendPrivateTransactionsProviderViewModel {
    var rows: [SendPrivateTransactionsProvider] = [
        .ethermine,
        .eden,
    ]

    var numberOfRows: Int {
        rows.count
    }
}
