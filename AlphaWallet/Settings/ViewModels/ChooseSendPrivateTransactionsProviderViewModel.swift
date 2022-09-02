// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import AlphaWalletFoundation

struct ChooseSendPrivateTransactionsProviderViewModel {
    var rows: [SendPrivateTransactionsProvider] = [
        .ethermine,
        .eden,
    ]

    var numberOfRows: Int {
        rows.count
    }
}
