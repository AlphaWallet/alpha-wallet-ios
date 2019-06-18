// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct AccountsViewModel {

    let wallets: [Wallet]

    init(wallets: [Wallet]) {
        self.wallets = wallets
    }

    var title: String {
        return R.string.localizable.walletNavigationTitle()
    }
}
